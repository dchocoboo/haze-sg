import WidgetKit
import SwiftUI

@main
struct HazeWidgetBundle: WidgetBundle {
    var body: some Widget {
        HazeWidget()
    }
}

struct HazeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HazeSGWidget",
            intent: SelectRegionIntent.self,
            provider: HazeProvider()
        ) { entry in
            HazeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Haze")
        .description("1-hour PM2.5 for a region of Singapore, with PSI alongside.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
