import SwiftUI
import HazeSGKit

/// The app's colour scale for severity.
///
/// Deliberately a green-to-maroon ramp following the common air quality
/// convention rather than a claim to be NEA's exact palette. Colour is only
/// ever reinforcement here: every place a band is shown, the band's word is
/// shown too, because Lock Screen widgets and tinted Home Screens strip
/// colour out entirely and a red/green ramp is the worst case for
/// colour-blind readers.
extension PSIBand {
    var color: Color {
        switch self {
        case .good: Color(red: 0.16, green: 0.65, blue: 0.40)
        case .moderate: Color(red: 0.85, green: 0.70, blue: 0.13)
        case .unhealthy: Color(red: 0.90, green: 0.49, blue: 0.13)
        case .veryUnhealthy: Color(red: 0.84, green: 0.22, blue: 0.22)
        case .hazardous: Color(red: 0.51, green: 0.11, blue: 0.20)
        }
    }
}

extension PM25Band {
    var color: Color {
        switch self {
        case .normal: Color(red: 0.16, green: 0.65, blue: 0.40)
        case .elevated: Color(red: 0.85, green: 0.70, blue: 0.13)
        case .high: Color(red: 0.90, green: 0.49, blue: 0.13)
        case .veryHigh: Color(red: 0.84, green: 0.22, blue: 0.22)
        }
    }
}

extension Region {
    var label: String {
        switch self {
        case .north: "North"
        case .south: "South"
        case .east: "East"
        case .west: "West"
        case .central: "Central"
        }
    }
}
