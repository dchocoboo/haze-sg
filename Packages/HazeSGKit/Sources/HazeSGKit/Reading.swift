import Foundation

/// One of NEA's five reporting regions.
///
/// NEA publishes a fixed representative coordinate per region. These are
/// convenience points for placing a region on a map, not polygons and not
/// station locations.
public enum Region: String, CaseIterable, Sendable, Codable, Hashable {
    case north, south, east, west, central

    public var latitude: Double {
        switch self {
        case .north: 1.41803
        case .south: 1.29587
        case .east, .west, .central: 1.35735
        }
    }

    public var longitude: Double {
        switch self {
        case .north, .south, .central: 103.82
        case .east: 103.94
        case .west: 103.70
        }
    }
}

public enum SourceID: String, Sendable, Codable, Hashable {
    case nea, openMeteo, purpleAir, google
}

public enum Metric: String, Sendable, Codable, Hashable {
    case psi, pm2_5, pm10, so2, co, o3, no2, usAQI
}

public enum Unit: String, Sendable, Codable, Hashable {
    /// Micrograms per cubic metre.
    case microgramsPerCubicMetre
    /// A dimensionless index such as PSI or US AQI. Index values from
    /// different scales are not comparable with each other.
    case index
}

/// A single measurement from a single source.
///
/// `windowMinutes` is the averaging window the source used, and it is the
/// reason this type exists rather than a bare number. Comparing a 24-hour
/// mean against an instantaneous reading measures the method, not the air,
/// so the window travels with the value everywhere it goes.
public struct Reading: Sendable, Codable, Hashable, Identifiable {
    public let source: SourceID
    public let region: Region?
    public let metric: Metric
    public let unit: Unit
    /// Averaging window in minutes. `0` means instantaneous.
    public let windowMinutes: Int
    public let observedAt: Date
    public let value: Double

    public var id: String {
        "\(source.rawValue)|\(region?.rawValue ?? "-")|\(metric.rawValue)|\(windowMinutes)|\(observedAt.timeIntervalSince1970)"
    }

    public init(
        source: SourceID,
        region: Region?,
        metric: Metric,
        unit: Unit,
        windowMinutes: Int,
        observedAt: Date,
        value: Double
    ) {
        self.source = source
        self.region = region
        self.metric = metric
        self.unit = unit
        self.windowMinutes = windowMinutes
        self.observedAt = observedAt
        self.value = value
    }
}
