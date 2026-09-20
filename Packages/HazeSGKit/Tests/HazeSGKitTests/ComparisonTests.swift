import Testing
import Foundation
@testable import HazeSGKit

private let noon = Date(timeIntervalSince1970: 1_789_880_400)

private func reading(
    _ source: SourceID,
    _ value: Double,
    metric: Metric = .pm2_5,
    unit: ReadingUnit = .microgramsPerCubicMetre,
    window: Int = 60,
    at date: Date = noon
) -> Reading {
    Reading(
        source: source,
        region: nil,
        metric: metric,
        unit: unit,
        windowMinutes: window,
        observedAt: date,
        value: value
    )
}

@Suite("Comparison refuses to compare incomparable things")
struct ComparisonGuardTests {

    @Test("rejects readings with different averaging windows")
    func rejectsMixedWindows() {
        // NEA's 24-hour PSI-era PM2.5 against a 1-hour reading. The gap
        // between these is mostly the window, not the air. This is the
        // single most likely way for the Compare screen to start lying.
        let readings = [
            reading(.nea, 36, window: 60),
            reading(.openMeteo, 21.9, window: 1440)
        ]

        #expect(throws: Comparison.Failure.mixedWindows([60, 1440])) {
            try Comparison.build(from: readings)
        }
    }

    @Test("rejects readings with different units")
    func rejectsMixedUnits() {
        let readings = [
            reading(.nea, 36, unit: .microgramsPerCubicMetre),
            reading(.openMeteo, 96, unit: .index)
        ]

        #expect(throws: Comparison.Failure.self) {
            try Comparison.build(from: readings)
        }
    }

    @Test("rejects readings of different metrics")
    func rejectsMixedMetrics() {
        let readings = [
            reading(.nea, 36, metric: .pm2_5),
            reading(.openMeteo, 26.2, metric: .pm10)
        ]

        #expect(throws: Comparison.Failure.self) {
            try Comparison.build(from: readings)
        }
    }

    @Test("rejects observations taken too far apart to be the same moment")
    func rejectsMisalignedTimestamps() {
        let readings = [
            reading(.nea, 36, at: noon),
            reading(.openMeteo, 21.9, at: noon.addingTimeInterval(3 * 3600))
        ]

        #expect(throws: Comparison.Failure.self) {
            try Comparison.build(from: readings)
        }
    }

    @Test("needs at least two sources to be a comparison at all")
    func rejectsSingleSource() {
        #expect(throws: Comparison.Failure.insufficientSources) {
            try Comparison.build(from: [reading(.nea, 36)])
        }
    }
}

@Suite("Comparison results")
struct ComparisonResultTests {

    private func twoSources() throws -> Comparison {
        try Comparison.build(from: [
            reading(.nea, 19),
            reading(.openMeteo, 21.9)
        ])
    }

    @Test("accepts NEA and Open-Meteo 1-hour PM2.5, which do match")
    func acceptsMatchedReadings() throws {
        let comparison = try twoSources()

        #expect(comparison.metric == .pm2_5)
        #expect(comparison.unit == .microgramsPerCubicMetre)
        #expect(comparison.windowMinutes == 60)
        #expect(comparison.entries.count == 2)
    }

    @Test("reports the spread between highest and lowest source")
    func reportsSpread() throws {
        // Recorded 2026-09-20 13:00 SGT: NEA north 19, Open-Meteo 21.9
        #expect(abs(try twoSources().spread - 2.9) < 0.0001)
    }

    @Test("orders entries from highest reading to lowest")
    func ordersEntries() throws {
        let comparison = try twoSources()

        #expect(comparison.entries.map(\.source) == [.openMeteo, .nea])
    }

    @Test("does not count NEA mirrors as corroboration")
    func mirrorsAreNotAgreement() throws {
        // A source that re-serves NEA will always match NEA exactly. Counting
        // that as two sources agreeing is the central trap this app exists to
        // avoid, so independent source count excludes both NEA and mirrors.
        let comparison = try Comparison.build(from: [
            reading(.nea, 19),
            reading(.openMeteo, 21.9)
        ])

        #expect(comparison.independentSourceCount == 1)
    }
}
