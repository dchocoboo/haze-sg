import SwiftUI
import HazeSGKit

@main
struct HazeSGApp: App {
    var body: some Scene {
        WindowGroup {
            NowView(
                model: NowViewModel(
                    service: AirQualityService(
                        sources: [NEASource(), OpenMeteoSource()]
                    )
                )
            )
        }
    }
}
