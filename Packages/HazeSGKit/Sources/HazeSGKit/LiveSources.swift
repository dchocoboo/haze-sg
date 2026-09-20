import Foundation

/// Fetches the bytes at a URL. Injected so sources can be tested against
/// recorded fixtures without touching the network.
public typealias Fetcher = @Sendable (URL) async throws -> Data

public enum Network {
    public static let urlSession: Fetcher = retrying { url in
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        // URLSession will happily cache a 429 and replay it long after the
        // rate limit has cleared, which leaves a widget permanently stuck on
        // "no reading". These payloads are small and change hourly, so
        // always go to the network.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SourceError.badStatus(http.statusCode)
        }
        return data
    }
}

/// Wraps a fetcher so transient failures are retried.
///
/// data.gov.sg rate-limits per 10-second window, and a widget waking on the
/// hour can easily collide with the app doing the same thing. A 429 is
/// temporary and worth one more try; a 404 is not, and retrying it would
/// just burn battery to get the same answer.
public func retrying(
    attempts: Int = 2,
    delay: TimeInterval = 2,
    _ fetch: @escaping Fetcher
) -> Fetcher {
    { url in
        var lastError: any Error = SourceError.badStatus(0)
        for attempt in 1...max(1, attempts) {
            do {
                return try await fetch(url)
            } catch {
                lastError = error
                guard Self_isTransient(error), attempt < attempts else { throw error }
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }
        throw lastError
    }
}

private func Self_isTransient(_ error: any Error) -> Bool {
    if case SourceError.badStatus(let code) = error {
        return code == 429 || (500..<600).contains(code)
    }
    return (error as? URLError) != nil
}

public enum SourceError: Error, Equatable {
    case badStatus(Int)
    case missingAPIKey
}

/// Singapore's National Environment Agency, via data.gov.sg.
///
/// Uses the v2 real-time endpoints. The legacy
/// `api.data.gov.sg/v1/environment/*` family still responds but is the
/// deprecated generation. Neither endpoint requires an API key; supplying one
/// only raises the rate limit.
public struct NEASource: AirQualitySource {
    public let id: SourceID = .nea

    static let psiURL = URL(string: "https://api-open.data.gov.sg/v2/real-time/api/psi")!
    static let pm25URL = URL(string: "https://api-open.data.gov.sg/v2/real-time/api/pm25")!

    private let fetch: Fetcher

    public init(fetch: @escaping Fetcher = Network.urlSession) {
        self.fetch = fetch
    }

    public func fetchCurrent() async throws -> [Reading] {
        async let psiData = fetch(Self.psiURL)
        async let pm25Data = fetch(Self.pm25URL)

        return try NEAParser.parsePSI(await psiData)
            + NEAParser.parsePM25(await pm25Data)
    }
}

/// Open-Meteo's air quality endpoint, serving CAMS model output.
///
/// No API key. Requests Singapore's centre, but the ~40km global grid snaps
/// the response elsewhere — see `OpenMeteoParser.Result.gridLatitude`.
public struct OpenMeteoSource: AirQualitySource {
    public let id: SourceID = .openMeteo

    /// Singapore, roughly the city centre.
    static let latitude = 1.3521
    static let longitude = 103.8198

    static var url: URL {
        var components = URLComponents(
            string: "https://air-quality-api.open-meteo.com/v1/air-quality"
        )!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "pm2_5,pm10,us_aqi"),
            .init(name: "timezone", value: "Asia/Singapore")
        ]
        return components.url!
    }

    private let fetch: Fetcher

    public init(fetch: @escaping Fetcher = Network.urlSession) {
        self.fetch = fetch
    }

    public func fetchCurrent() async throws -> [Reading] {
        try OpenMeteoParser.parse(await fetch(Self.url)).readings
    }
}
