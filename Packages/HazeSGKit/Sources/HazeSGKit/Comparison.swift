import Foundation

/// A like-for-like comparison of one metric across several sources.
///
/// The type exists to make an unfair comparison impossible to construct.
/// `build(from:)` refuses any set of readings that differ in metric, unit or
/// averaging window, or that were observed too far apart to describe the same
/// air. Those differences produce large, convincing, meaningless gaps — a
/// 24-hour mean against an instantaneous reading will always look like
/// disagreement even when both sources are perfectly correct.
public struct Comparison: Sendable, Equatable {

    public enum Failure: Error, Equatable {
        case insufficientSources
        case mixedMetrics([Metric])
        case mixedUnits([ReadingUnit])
        case mixedWindows([Int])
        /// Observations spread further apart in time than `tolerance`.
        case misalignedObservations(spreadSeconds: TimeInterval)
    }

    public struct Entry: Sendable, Equatable, Identifiable {
        public let source: SourceID
        public let value: Double
        public let observedAt: Date
        public var descriptor: SourceDescriptor { .describing(source) }
        public var id: SourceID { source }
    }

    public let metric: Metric
    public let unit: ReadingUnit
    public let windowMinutes: Int
    /// Highest reading first.
    public let entries: [Entry]

    /// Difference between the highest and lowest reading, in `unit`.
    public var spread: Double {
        guard let high = entries.first?.value, let low = entries.last?.value else {
            return 0
        }
        return high - low
    }

    /// How many entries are genuinely independent of NEA.
    ///
    /// Excludes NEA itself and anything that re-serves it. A comparison with
    /// a count of zero is not corroboration however many rows it shows.
    public var independentSourceCount: Int {
        entries.filter { $0.descriptor.kind.isIndependent }.count
    }

    /// Builds a comparison, or refuses.
    ///
    /// - Parameter tolerance: how far apart observations may be and still be
    ///   treated as the same moment. Defaults to one hour, matching the
    ///   publishing cadence of the hourly sources.
    public static func build(
        from readings: [Reading],
        tolerance: TimeInterval = 3600
    ) throws -> Comparison {
        guard readings.count >= 2 else { throw Failure.insufficientSources }

        let metrics = Set(readings.map(\.metric))
        guard metrics.count == 1, let metric = metrics.first else {
            throw Failure.mixedMetrics(metrics.sorted { $0.rawValue < $1.rawValue })
        }

        let units = Set(readings.map(\.unit))
        guard units.count == 1, let unit = units.first else {
            throw Failure.mixedUnits(units.sorted { $0.rawValue < $1.rawValue })
        }

        let windows = Set(readings.map(\.windowMinutes))
        guard windows.count == 1, let window = windows.first else {
            throw Failure.mixedWindows(windows.sorted())
        }

        let times = readings.map(\.observedAt)
        if let earliest = times.min(), let latest = times.max() {
            let spread = latest.timeIntervalSince(earliest)
            guard spread <= tolerance else {
                throw Failure.misalignedObservations(spreadSeconds: spread)
            }
        }

        let entries = readings
            .map { Entry(source: $0.source, value: $0.value, observedAt: $0.observedAt) }
            .sorted { $0.value > $1.value }

        guard Set(entries.map(\.source)).count >= 2 else {
            throw Failure.insufficientSources
        }

        return Comparison(
            metric: metric,
            unit: unit,
            windowMinutes: window,
            entries: entries
        )
    }
}
