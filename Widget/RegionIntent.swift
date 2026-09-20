import AppIntents
import HazeSGKit

/// Which of NEA's five regions a widget instance shows.
///
/// Configurable per instance, so two widgets can sit side by side showing
/// home and the office.
enum WidgetRegion: String, AppEnum {
    case north, south, east, west, central

    var region: Region { Region(rawValue: rawValue) ?? .central }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Region" }

    static var caseDisplayRepresentations: [WidgetRegion: DisplayRepresentation] {
        [
            .north: "North",
            .south: "South",
            .east: "East",
            .west: "West",
            .central: "Central"
        ]
    }
}

struct SelectRegionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Select Region" }
    static var description: IntentDescription {
        IntentDescription("Choose which part of Singapore to show.")
    }

    @Parameter(title: "Region", default: .central)
    var region: WidgetRegion
}
