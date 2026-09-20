import Testing
import Foundation
@testable import HazeSGKit

/// A source that returns canned readings or throws, so failure isolation can
/// be tested without touching the network.
private struct StubSource: AirQualitySource {
    let id: SourceID
    var isConfigured: Bool = true
    let result: Result<[Reading], any Error>

    func fetchCurrent() async throws -> [Reading] {
        try result.get()
    }
}

private struct Boom: Error {}

private func reading(_ source: SourceID, _ value: Double) -> Reading {
    Reading(
        source: source,
        region: .central,
        metric: .pm2_5,
        unit: .microgramsPerCubicMetre,
        windowMinutes: 60,
        observedAt: Date(timeIntervalSince1970: 1_789_880_400),
        value: value
    )
}

@Suite("AirQualityService fetches sources independently")
struct AirQualityServiceTests {

    @Test("one source failing does not lose the others' readings")
    func failureIsIsolated() async {
        let service = AirQualityService(sources: [
            StubSource(id: .nea, result: .success([reading(.nea, 36)])),
            StubSource(id: .openMeteo, result: .failure(Boom()))
        ])

        let snapshot = await service.fetchAll()

        #expect(snapshot.readings.map(\.source) == [.nea])
        #expect(snapshot.failures.keys.contains(.openMeteo))
    }

    @Test("records why a source failed rather than dropping it silently")
    func failureIsReported() async {
        let service = AirQualityService(sources: [
            StubSource(id: .nea, result: .success([reading(.nea, 36)])),
            StubSource(id: .openMeteo, result: .failure(Boom()))
        ])

        let snapshot = await service.fetchAll()

        #expect(snapshot.failures.count == 1)
        #expect(snapshot.status(for: .openMeteo) == .failed)
        #expect(snapshot.status(for: .nea) == .ok)
    }

    @Test("skips sources with no API key instead of failing them")
    func unconfiguredSourcesAreSkippedNotFailed() async {
        // A missing optional key is an empty state to fill in, not an error
        // to apologise for.
        let service = AirQualityService(sources: [
            StubSource(id: .nea, result: .success([reading(.nea, 36)])),
            StubSource(id: .purpleAir, isConfigured: false, result: .failure(Boom()))
        ])

        let snapshot = await service.fetchAll()

        #expect(snapshot.failures.isEmpty)
        #expect(snapshot.status(for: .purpleAir) == .notConfigured)
    }

    @Test("collects readings from every source that succeeded")
    func collectsAllSuccesses() async {
        let service = AirQualityService(sources: [
            StubSource(id: .nea, result: .success([reading(.nea, 36)])),
            StubSource(id: .openMeteo, result: .success([reading(.openMeteo, 21.9)]))
        ])

        let snapshot = await service.fetchAll()

        #expect(Set(snapshot.readings.map(\.source)) == [.nea, .openMeteo])
    }

    @Test("builds a comparison from a snapshot when sources are comparable")
    func buildsComparisonFromSnapshot() async throws {
        let service = AirQualityService(sources: [
            StubSource(id: .nea, result: .success([reading(.nea, 19)])),
            StubSource(id: .openMeteo, result: .success([reading(.openMeteo, 21.9)]))
        ])

        let snapshot = await service.fetchAll()
        let comparison = try #require(snapshot.comparison(of: .pm2_5, in: .central))

        #expect(comparison.entries.count == 2)
        #expect(abs(comparison.spread - 2.9) < 0.0001)
    }
}
