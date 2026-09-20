import Foundation

/// How a source relates to NEA's reference network.
///
/// This distinction is the reason the app exists. NEA runs the only reference
/// monitoring network in Singapore, so a service showing an "official
/// Singapore station" is re-serving NEA's own numbers. Presenting that as a
/// second opinion would show perfect agreement that means nothing.
public enum SourceKind: Sendable, Hashable {
    /// NEA itself — the reference network.
    case reference
    /// Independent physical sensors in Singapore.
    case independentMeasured
    /// An independent model with no Singapore ground input.
    case independentModelled
    /// Re-serves NEA's readings. Never counts as corroboration.
    case mirrorsReference

    public var isIndependent: Bool {
        switch self {
        case .independentMeasured, .independentModelled: true
        case .reference, .mirrorsReference: false
        }
    }
}

public struct SourceDescriptor: Sendable, Hashable {
    public let id: SourceID
    public let displayName: String
    public let kind: SourceKind
    /// Plain-language reason this source may read differently from the
    /// others. Shown next to the number so a divergence reads as an
    /// explicable difference in method rather than as someone being wrong.
    public let caveat: String?
    public let attribution: String
    public let attributionURL: URL?

    public static let all: [SourceID: SourceDescriptor] = [
        .nea: .init(
            id: .nea,
            displayName: "NEA",
            kind: .reference,
            caveat: nil,
            attribution: """
                Air quality data from the National Environment Agency via \
                data.gov.sg, used under the Singapore Open Data Licence. \
                Not endorsed by or affiliated with NEA.
                """,
            attributionURL: URL(string: "https://data.gov.sg/open-data-licence")
        ),
        .openMeteo: .init(
            id: .openMeteo,
            displayName: "Open-Meteo",
            kind: .independentModelled,
            caveat: """
                A weather model, not a sensor. Its grid cell is about 40km \
                across, so it reports one figure for all of Singapore and \
                cannot see differences between regions.
                """,
            attribution: "Air quality model output from Open-Meteo (CAMS).",
            attributionURL: URL(string: "https://open-meteo.com/")
        ),
        .purpleAir: .init(
            id: .purpleAir,
            displayName: "PurpleAir",
            kind: .independentMeasured,
            caveat: """
                Low-cost optical sensors, which read high in humid air. \
                Singapore is humid almost always, so expect these numbers to \
                sit above NEA's rather than assume either is wrong.
                """,
            attribution: "Sensor data from PurpleAir.",
            attributionURL: URL(string: "https://www2.purpleair.com/")
        ),
        .google: .init(
            id: .google,
            displayName: "Google",
            kind: .independentModelled,
            caveat: """
                A model blending satellite, weather and traffic data rather \
                than a direct measurement.
                """,
            attribution: "Air quality data from Google Maps Platform.",
            attributionURL: URL(string: "https://developers.google.com/maps/documentation/air-quality")
        )
    ]

    public static func describing(_ id: SourceID) -> SourceDescriptor {
        all[id] ?? .init(
            id: id,
            displayName: id.rawValue,
            kind: .independentModelled,
            caveat: nil,
            attribution: id.rawValue,
            attributionURL: nil
        )
    }
}
