import Foundation

/// Fetches the bytes at a URL. Injected so sources can be tested against
/// recorded fixtures without touching the network.
public typealias Fetcher = @Sendable (URL) async throws -> Data

public enum Network {
    public static let urlSession: Fetcher = { url in
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SourceError.badStatus(http.statusCode)
        }
        return data
    }
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
