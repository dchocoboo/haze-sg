import Testing
import Foundation
@testable import HazeSGKit

/// Hits the real endpoints. Off by default so the normal suite stays fast and
/// offline; run with `HAZE_LIVE=1 swift test` to exercise the real code path
/// against live data.
private let liveEnabled = ProcessInfo.processInfo.environment["HAZE_LIVE"] != nil

@Suite("Live network", .enabled(if: liveEnabled))
struct LiveNetworkTests {

    @Test("NEA returns PSI and PM2.5 for all five regions right now")
    func neaLive() async throws {
        let readings = try await NEASource().fetchCurrent()

        #expect(readings.filter { $0.metric == .psi }.count == 5)
        #expect(readings.filter { $0.metric == .pm2_5 }.count == 5)
        // Sanity: a PSI outside this range means the shape changed.
        #expect(readings.filter { $0.metric == .psi }.allSatisfy { (0...500).contains($0.value) })
    }

    @Test("Open-Meteo returns a current PM2.5 for Singapore right now")
    func openMeteoLive() async throws {
        let readings = try await OpenMeteoSource().fetchCurrent()
        let pm25 = try #require(readings.first { $0.metric == .pm2_5 })

        #expect(pm25.windowMinutes == 60)
        #expect(pm25.value >= 0)
    }

    @Test("the two sources can actually be compared against each other")
    func comparisonLive() async throws {
        // The end-to-end proof that the design works on live data: two
        // independent sources, same metric, same unit, same window, close
        // enough in time to describe the same air.
        let service = AirQualityService(sources: [NEASource(), OpenMeteoSource()])
        let snapshot = await service.fetchAll()

        #expect(snapshot.failures.isEmpty)

        let comparison = try #require(snapshot.comparison(of: .pm2_5, in: .north))
        #expect(comparison.entries.count == 2)
        #expect(comparison.independentSourceCount == 1)

        print("LIVE north PM2.5 1h:", comparison.entries.map {
            "\($0.descriptor.displayName)=\($0.value)"
        }.joined(separator: " "), "| spread:", comparison.spread)
    }
}
