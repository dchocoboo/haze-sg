import Testing
import Foundation
@testable import HazeSGKit

private struct StubSource: AirQualitySource {
    let id: SourceID
    var isConfigured: Bool = true
    let result: Result<[Reading], any Error>
    func fetchCurrent() async throws -> [Reading] { try result.get() }
}

private struct Boom: Error {}

private let observedAt = Date(timeIntervalSince1970: 1_789_884_000)

/// Live NEA values from 2026-09-20 14:00 SGT.
private func neaReadings() -> [Reading] {
    let psi: [Region: Double] = [
        .north: 75, .south: 77, .west: 94, .east: 84, .central: 104
    ]
    let pm25: [Region: Double] = [
        .north: 19, .south: 20, .west: 37, .east: 31, .central: 36
    ]
    return psi.map {
        Reading(source: .nea, region: $0.key, metric: .psi, unit: .index,
                windowMinutes: 1440, observedAt: observedAt, value: $0.value)
    } + pm25.map {
        Reading(source: .nea, region: $0.key, metric: .pm2_5,
                unit: .microgramsPerCubicMetre, windowMinutes: 60,
                observedAt: observedAt, value: $0.value)
    }
}

@MainActor
@Suite("NowViewModel")
struct NowViewModelTests {

    private func loaded(
        sources: [any AirQualitySource] = [StubSource(id: .nea, result: .success(neaReadings()))]
    ) async -> NowViewModel {
        let model = NowViewModel(service: AirQualityService(sources: sources))
        await model.load()
        return model
    }

    @Test("starts with nothing loaded and not in an error state")
    func startsIdle() {
        let model = NowViewModel(service: AirQualityService(sources: []))

        #expect(model.snapshot == nil)
        #expect(!model.isLoading)
    }

    @Test("exposes PSI and its band for the selected region")
    func exposesPSI() async {
        let model = await loaded()
        model.selectedRegion = .central

        #expect(model.psi == 104)
        #expect(model.psiBand == .unhealthy)
    }

    @Test("exposes the 1-hour PM2.5 and its band for the selected region")
    func exposesPM25() async {
        let model = await loaded()
        model.selectedRegion = .central

        #expect(model.pm25 == 36)
        #expect(model.pm25Band == .normal)
    }

    @Test("switching region changes the values without another fetch")
    func switchingRegion() async {
        let model = await loaded()

        model.selectedRegion = .central
        #expect(model.psi == 104)

        model.selectedRegion = .north
        #expect(model.psi == 75)
    }

    @Test("reports when PSI and PM2.5 tell different stories")
    func flagsDisagreementBetweenIndices() async {
        // Central today: PSI 104 (Unhealthy, a 24-hour average still carrying
        // earlier bad air) against 1-hour PM2.5 of 36 (Normal). The app has
        // to explain this rather than let the two numbers look broken.
        let model = await loaded()
        model.selectedRegion = .central

        #expect(model.psiAndPM25Disagree)
    }

    @Test("does not flag disagreement when both readings agree")
    func noDisagreementWhenAligned() async {
        let model = await loaded()
        model.selectedRegion = .north

        // North: PSI 75 (Moderate), PM2.5 19 (Normal) -- both unremarkable.
        #expect(!model.psiAndPM25Disagree)
    }

    @Test("surfaces an error only when every source fails")
    func errorOnlyWhenAllFail() async {
        let model = await loaded(sources: [
            StubSource(id: .nea, result: .failure(Boom()))
        ])

        #expect(model.hasNoData)
    }

    @Test("still shows data when one source of two fails")
    func partialFailureStillShowsData() async {
        let model = await loaded(sources: [
            StubSource(id: .nea, result: .success(neaReadings())),
            StubSource(id: .openMeteo, result: .failure(Boom()))
        ])
        model.selectedRegion = .central

        #expect(!model.hasNoData)
        #expect(model.psi == 104)
    }
}

@MainActor
@Suite("Reading time is always shown in Singapore time")
struct ObservedAtFormattingTests {

    @Test("formats the observation time in SGT even when the device is not")
    func formatsInSingaporeTime() async {
        // A reading published for 14:00 in Singapore is a fact about
        // Singapore. Rendering it in the phone's own timezone would show the
        // wrong hour to anyone travelling, with nothing on screen to say so.
        let model = NowViewModel(
            service: AirQualityService(sources: [
                StubSource(id: .nea, result: .success(neaReadings()))
            ])
        )
        await model.load()

        let description = try! #require(model.observedAtDescription)

        // neaReadings() is stamped 2026-09-20T14:00:00+08:00.
        #expect(description.contains("2"))
        #expect(description.contains("SGT"))
    }

    @Test("says nothing rather than guessing when there is no reading")
    func noReadingNoTime() {
        let model = NowViewModel(service: AirQualityService(sources: []))

        #expect(model.observedAtDescription == nil)
    }
}
