import Testing
import Foundation
@testable import HazeSGKit

private let at = Date(timeIntervalSince1970: 1_789_884_000)

private func snapshot(psi: Double, pm25: Double, region: Region = .central) -> Snapshot {
    Snapshot(
        readings: [
            Reading(source: .nea, region: region, metric: .psi, unit: .index,
                    windowMinutes: 1440, observedAt: at, value: psi),
            Reading(source: .nea, region: region, metric: .pm2_5,
                    unit: .microgramsPerCubicMetre, windowMinutes: 60,
                    observedAt: at, value: pm25)
        ],
        failures: [:],
        unconfigured: []
    )
}

@Suite("Conditions")
struct ConditionsTests {

    @Test("leads with the 1-hour PM2.5, because that is what you act on")
    func pm25IsPrimary() throws {
        let c = try #require(snapshot(psi: 104, pm25: 36).conditions(for: .central))

        // The headline reading and its band are the 1-hour PM2.5. PSI is
        // carried alongside as context, not as the answer.
        #expect(c.pm25 == 36)
        #expect(c.pm25Band == .normal)
        #expect(c.psi == 104)
        #expect(c.psiBand == .unhealthy)
    }

    @Test("a widget can render from PM2.5 alone when PSI is missing")
    func worksWithoutPSI() throws {
        let partial = Snapshot(
            readings: [
                Reading(source: .nea, region: .north, metric: .pm2_5,
                        unit: .microgramsPerCubicMetre, windowMinutes: 60,
                        observedAt: at, value: 19)
            ],
            failures: [:], unconfigured: []
        )

        let c = try #require(partial.conditions(for: .north))
        #expect(c.pm25 == 19)
        #expect(c.psi == nil)
    }

    @Test("is nil when there is no PM2.5 to lead with")
    func nilWithoutPM25() {
        let psiOnly = Snapshot(
            readings: [
                Reading(source: .nea, region: .north, metric: .psi, unit: .index,
                        windowMinutes: 1440, observedAt: at, value: 75)
            ],
            failures: [:], unconfigured: []
        )

        #expect(psiOnly.conditions(for: .north) == nil)
    }

    @Test("gauge fill comes from the band so severity survives without colour")
    func severityWithoutColour() throws {
        let c = try #require(snapshot(psi: 104, pm25: 260).conditions(for: .central))

        #expect(c.pm25Band == .veryHigh)
        #expect(c.severity == 1.0)
    }
}
