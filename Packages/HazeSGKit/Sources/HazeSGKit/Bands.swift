import Foundation

/// NEA's published PSI descriptor bands.
///
/// PSI is a 24-hour average, so it lags. On a clearing day it can still read
/// Unhealthy while the air outside right now is fine. NEA's own advice is to
/// use the 1-hour PM2.5 reading for anything you are about to do in the next
/// hour, which is why the app shows `PM25Band` alongside this one rather than
/// treating PSI as the whole answer.
public enum PSIBand: String, CaseIterable, Sendable, Hashable {
    case good, moderate, unhealthy, veryUnhealthy, hazardous

    public init(psi: Double) {
        switch psi {
        case ..<51: self = .good
        case ..<101: self = .moderate
        case ..<201: self = .unhealthy
        case ..<301: self = .veryUnhealthy
        default: self = .hazardous
        }
    }

    /// The word that carries the meaning where colour cannot — Lock Screen
    /// widgets, tinted Home Screens, and for colour-blind readers.
    public var label: String {
        switch self {
        case .good: "Good"
        case .moderate: "Moderate"
        case .unhealthy: "Unhealthy"
        case .veryUnhealthy: "Very Unhealthy"
        case .hazardous: "Hazardous"
        }
    }

    /// How full a gauge should be, so severity survives without colour.
    public var severity: Double {
        switch self {
        case .good: 0.2
        case .moderate: 0.4
        case .unhealthy: 0.6
        case .veryUnhealthy: 0.8
        case .hazardous: 1.0
        }
    }
}

/// NEA's 1-hour PM2.5 concentration bands, in µg/m³.
///
/// This is the reading NEA points people to for immediate decisions.
public enum PM25Band: String, CaseIterable, Sendable, Hashable {
    case normal, elevated, high, veryHigh

    public init(microgramsPerCubicMetre value: Double) {
        switch value {
        case ..<56: self = .normal
        case ..<151: self = .elevated
        case ..<251: self = .high
        default: self = .veryHigh
        }
    }

    public var label: String {
        switch self {
        case .normal: "Normal"
        case .elevated: "Elevated"
        case .high: "High"
        case .veryHigh: "Very High"
        }
    }

    public var severity: Double {
        switch self {
        case .normal: 0.25
        case .elevated: 0.5
        case .high: 0.75
        case .veryHigh: 1.0
        }
    }
}
