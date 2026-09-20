import Foundation

/// One provider of air quality readings.
///
/// Implementations normalise whatever their API returns into `Reading`s, so
/// that everything downstream — and the Compare screen in particular — works
/// in one vocabulary with the averaging window attached.
public protocol AirQualitySource: Sendable {
    var id: SourceID { get }
    /// `false` when the source needs an API key the user has not supplied.
    /// An unconfigured source is an empty state, not a failure.
    var isConfigured: Bool { get }
    func fetchCurrent() async throws -> [Reading]
}

public extension AirQualitySource {
    var isConfigured: Bool { true }
    var descriptor: SourceDescriptor { .describing(id) }
}

/// What happened to one source during a fetch.
public enum SourceStatus: Sendable, Equatable {
    case ok
    case failed
    /// Needs an API key that has not been supplied.
    case notConfigured
}

/// The result of fetching every source once.
public struct Snapshot: Sendable {
    public let readings: [Reading]
    public let failures: [SourceID: String]
    public let unconfigured: Set<SourceID>
    public let fetchedAt: Date

    public init(
        readings: [Reading],
        failures: [SourceID: String],
        unconfigured: Set<SourceID>,
        fetchedAt: Date = Date()
    ) {
        self.readings = readings
        self.failures = failures
        self.unconfigured = unconfigured
        self.fetchedAt = fetchedAt
    }

    public func status(for source: SourceID) -> SourceStatus {
        if unconfigured.contains(source) { return .notConfigured }
        if failures[source] != nil { return .failed }
        return .ok
    }

    public func readings(for source: SourceID) -> [Reading] {
        readings.filter { $0.source == source }
    }

    /// A like-for-like comparison of one metric in one region.
    ///
    /// Sources with no region of their own — a coarse model cell standing in
    /// for the whole island — are included wherever the region is asked for,
    /// because they describe all of it. Returns `nil` rather than throwing
    /// when a fair comparison cannot be built; a screen with one source is a
    /// normal state, not an error.
    public func comparison(of metric: Metric, in region: Region) -> Comparison? {
        let candidates = readings.filter {
            $0.metric == metric && ($0.region == region || $0.region == nil)
        }
        return try? Comparison.build(from: candidates)
    }
}

/// Fetches every source concurrently, isolating failures.
///
/// One source being down, rate-limited or unconfigured must never stop the
/// others from rendering — on a hazy day the app has to show whatever it can
/// get rather than an error page.
public struct AirQualityService: Sendable {
    private let sources: [any AirQualitySource]

    public init(sources: [any AirQualitySource]) {
        self.sources = sources
    }

    public func fetchAll() async -> Snapshot {
        let configured = sources.filter(\.isConfigured)
        let unconfigured = Set(
            sources.filter { !$0.isConfigured }.map(\.id)
        )

        var readings: [Reading] = []
        var failures: [SourceID: String] = [:]

        await withTaskGroup(
            of: (SourceID, Result<[Reading], any Error>).self
        ) { group in
            for source in configured {
                group.addTask {
                    do {
                        return (source.id, .success(try await source.fetchCurrent()))
                    } catch {
                        return (source.id, .failure(error))
                    }
                }
            }

            for await (id, result) in group {
                switch result {
                case .success(let values): readings.append(contentsOf: values)
                case .failure(let error): failures[id] = String(describing: error)
                }
            }
        }

        return Snapshot(
            readings: readings,
            failures: failures,
            unconfigured: unconfigured
        )
    }
}
