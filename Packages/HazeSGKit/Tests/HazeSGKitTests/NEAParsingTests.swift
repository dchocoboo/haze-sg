import Testing
import Foundation
@testable import HazeSGKit

@Suite("NEA PSI parsing")
struct NEAPSIParsingTests {

    @Test("produces a 24-hour PSI reading for each of the five regions")
    func parsesPSIForAllRegions() throws {
        let readings = try NEAParser.parsePSI(try Fixture.data("nea_psi"))

        let psi = readings.filter { $0.metric == .psi }
        #expect(psi.count == 5)
        #expect(Set(psi.map(\.region)) == Set(Region.allCases))
    }

    @Test("reads the recorded PSI values, keyed to the right region")
    func parsesRecordedPSIValues() throws {
        let readings = try NEAParser.parsePSI(try Fixture.data("nea_psi"))

        // Recorded 2026-09-20 13:00 SGT
        let expected: [Region: Double] = [
            .north: 77, .south: 80, .west: 97, .east: 87, .central: 107
        ]
        for (region, value) in expected {
            let reading = try #require(
                readings.first { $0.metric == .psi && $0.region == region }
            )
            #expect(reading.value == value)
        }
    }

    @Test("tags PSI as a 24-hour window on an index scale")
    func psiCarriesItsWindowAndUnit() throws {
        let readings = try NEAParser.parsePSI(try Fixture.data("nea_psi"))
        let psi = try #require(readings.first { $0.metric == .psi })

        #expect(psi.windowMinutes == 1440)
        #expect(psi.unit == .index)
        #expect(psi.source == .nea)
    }

    @Test("parses the observation timestamp in Singapore time")
    func parsesTimestamp() throws {
        let readings = try NEAParser.parsePSI(try Fixture.data("nea_psi"))
        let psi = try #require(readings.first)

        // The fixture records 2026-09-20T13:00:00+08:00. Building the
        // expected date from components rather than an epoch literal, so a
        // failure here means the parser is wrong and not that the arithmetic
        // in this test is.
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 20
        components.hour = 13
        components.timeZone = TimeZone(identifier: "Asia/Singapore")
        let expected = try #require(Calendar(identifier: .gregorian).date(from: components))

        #expect(psi.observedAt == expected)
    }
}

@Suite("NEA PM2.5 parsing")
struct NEAPM25ParsingTests {

    @Test("produces a 1-hour PM2.5 reading for each of the five regions")
    func parsesPM25ForAllRegions() throws {
        let readings = try NEAParser.parsePM25(try Fixture.data("nea_pm25"))

        #expect(readings.count == 5)
        #expect(Set(readings.map(\.region)) == Set(Region.allCases))
        #expect(readings.allSatisfy { $0.metric == .pm2_5 })
    }

    @Test("reads the recorded PM2.5 values, keyed to the right region")
    func parsesRecordedPM25Values() throws {
        let readings = try NEAParser.parsePM25(try Fixture.data("nea_pm25"))

        // Recorded 2026-09-20 13:00 SGT
        let expected: [Region: Double] = [
            .north: 19, .south: 20, .west: 37, .east: 31, .central: 36
        ]
        for (region, value) in expected {
            let reading = try #require(readings.first { $0.region == region })
            #expect(reading.value == value)
        }
    }

    @Test("tags PM2.5 as a 1-hour mean in micrograms per cubic metre")
    func pm25CarriesItsWindowAndUnit() throws {
        let reading = try #require(
            try NEAParser.parsePM25(try Fixture.data("nea_pm25")).first
        )

        // These two facts are what make this reading comparable against
        // other sources. If either changes, the Compare screen is lying.
        #expect(reading.windowMinutes == 60)
        #expect(reading.unit == .microgramsPerCubicMetre)
    }
}

@Suite("NEA parser error handling")
struct NEAParserErrorTests {

    @Test("throws rather than returning nothing when the payload has no items")
    func emptyItemsThrows() throws {
        let empty = Data(#"{"code":0,"data":{"items":[]},"errorMsg":""}"#.utf8)

        #expect(throws: NEAParser.ParseError.noItems) {
            try NEAParser.parsePSI(empty)
        }
    }

    @Test("throws on an unparseable timestamp rather than silently using now")
    func badTimestampThrows() throws {
        let bad = Data(#"""
        {"code":0,"data":{"items":[
          {"timestamp":"not a date","readings":{"psi_twenty_four_hourly":{"north":50}}}
        ]},"errorMsg":""}
        """#.utf8)

        #expect(throws: NEAParser.ParseError.badTimestamp("not a date")) {
            try NEAParser.parsePSI(bad)
        }
    }
}
