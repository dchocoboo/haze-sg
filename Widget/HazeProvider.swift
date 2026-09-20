import WidgetKit
import HazeSGKit
import Foundation

struct HazeEntry: TimelineEntry {
    let date: Date
    let region: Region
    let conditions: Conditions?
}

struct HazeProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> HazeEntry {
        HazeEntry(date: .now, region: .central, conditions: .preview)
    }

    func snapshot(for configuration: SelectRegionIntent, in context: Context) async -> HazeEntry {
        await entry(for: configuration.region.region)
    }

    func timeline(
        for configuration: SelectRegionIntent,
        in context: Context
    ) async -> Timeline<HazeEntry> {
        let region = configuration.region.region
        let entry = await entry(for: region)

        // NEA publishes hourly, at or shortly after the top of the hour. If
        // we already have this hour's reading, wait for the next one; if we
        // got the previous hour's, try again soon rather than sitting stale
        // for an hour.
        let reload: Date
        if let observedAt = entry.conditions?.observedAt,
           Calendar.current.isDate(observedAt, equalTo: .now, toGranularity: .hour) {
            reload = Self.nextHour(after: .now)
        } else {
            reload = Date.now.addingTimeInterval(10 * 60)
        }

        return Timeline(entries: [entry], policy: .after(reload))
    }

    /// Only the keyless sources run here. PurpleAir and Google bill the
    /// user's own key, and a widget waking hourly on every device is the
    /// wrong place to spend that quota.
    private func entry(for region: Region) async -> HazeEntry {
        let service = AirQualityService(sources: [NEASource()])
        let snapshot = await service.fetchAll()
        return HazeEntry(
            date: .now,
            region: region,
            conditions: snapshot.conditions(for: region)
        )
    }

    private static func nextHour(after date: Date) -> Date {
        let calendar = Calendar.current
        let next = calendar.date(byAdding: .hour, value: 1, to: date) ?? date.addingTimeInterval(3600)
        return calendar.date(
            bySetting: .minute, value: 2,
            of: calendar.date(bySetting: .second, value: 0, of: next) ?? next
        ) ?? next
    }
}

extension Conditions {
    /// Stand-in for placeholders and previews. Real haze-day numbers rather
    /// than invented ones.
    static let preview = Conditions(
        region: .central,
        pm25: 36,
        psi: 104,
        observedAt: .now
    )
}
