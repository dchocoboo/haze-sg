import Testing
import Foundation
@testable import HazeSGKit

@Suite("Open-Meteo parsing")
struct OpenMeteoParsingTests {

    private func parse() throws -> OpenMeteoParser.Result {
        try OpenMeteoParser.parse(try Fixture.data("open_meteo"))
    }

    @Test("reads the recorded current PM2.5 value")
    func parsesPM25() throws {
        let pm25 = try #require(
            try parse().readings.first { $0.metric == .pm2_5 }
        )

        #expect(pm25.value == 21.9)
        #expect(pm25.source == .openMeteo)
    }

    @Test("tags PM2.5 as a 1-hour mean in micrograms per cubic metre")
    func pm25MatchesNEAsWindowAndUnit() throws {
        let pm25 = try #require(
            try parse().readings.first { $0.metric == .pm2_5 }
        )

        // Open-Meteo's `current` is the model's value for the current hour,
        // and `interval` in the fixture is 3600. Matching NEA's 1-hour mean
        // in the same unit is precisely what makes the two comparable.
        #expect(pm25.windowMinutes == 60)
        #expect(pm25.unit == .microgramsPerCubicMetre)
    }

    @Test("has no region, because one grid cell cannot resolve five of them")
    func hasNoRegion() throws {
        #expect(try parse().readings.allSatisfy { $0.region == nil })
    }

    @Test("resolves the local naive timestamp using the offset field")
    func parsesTimestampViaOffset() throws {
        // The fixture says "2026-09-20T13:00" with no offset in the string,
        // and carries utc_offset_seconds = 28800 separately. Reading the
        // string as UTC would put the reading 8 hours out and silently
        // misalign it against NEA.
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 20
        components.hour = 13
        components.timeZone = TimeZone(identifier: "Asia/Singapore")
        let expected = try #require(Calendar(identifier: .gregorian).date(from: components))

        let pm25 = try #require(try parse().readings.first { $0.metric == .pm2_5 })
        #expect(pm25.observedAt == expected)
    }

    @Test("reports US AQI as an index, not as a concentration")
    func usAQIIsAnIndex() throws {
        let aqi = try #require(try parse().readings.first { $0.metric == .usAQI })

        #expect(aqi.value == 96)
        #expect(aqi.unit == .index)
    }

    @Test("reports the grid point the request was snapped to")
    func reportsGridPoint() throws {
        // Requested 1.3521/103.8198; the ~40km CAMS cell snaps elsewhere.
        // The UI has to be able to disclose this, so the parser surfaces it.
        let result = try parse()

        #expect(abs(result.gridLatitude - 1.40) < 0.01)
        #expect(abs(result.gridLongitude - 103.80) < 0.01)
    }
}
