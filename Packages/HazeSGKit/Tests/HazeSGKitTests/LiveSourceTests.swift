import Testing
import Foundation
@testable import HazeSGKit

@Suite("NEASource")
struct NEASourceTests {

    @Test("combines the PSI and PM2.5 endpoints into one set of readings")
    func combinesBothEndpoints() async throws {
        let source = NEASource { url in
            url.absoluteString.contains("pm25")
                ? try Fixture.data("nea_pm25")
                : try Fixture.data("nea_psi")
        }

        let readings = try await source.fetchCurrent()

        // 5 regions of 24h PSI + 5 regions of 1h PM2.5
        #expect(readings.filter { $0.metric == .psi }.count == 5)
        #expect(readings.filter { $0.metric == .pm2_5 }.count == 5)
    }

    @Test("requests the v2 endpoints, not the deprecated v1 family")
    func usesV2Endpoints() async throws {
        let recorder = URLRecorder()
        let source = NEASource { url in
            await recorder.record(url)
            return url.absoluteString.contains("pm25")
                ? try Fixture.data("nea_pm25")
                : try Fixture.data("nea_psi")
        }

        _ = try await source.fetchCurrent()
        let urls = await recorder.urls

        #expect(urls.count == 2)
        #expect(urls.allSatisfy { $0.contains("api-open.data.gov.sg/v2/real-time/api/") })
        #expect(!urls.contains { $0.contains("/v1/environment/") })
    }

    @Test("needs no API key")
    func needsNoKey() {
        #expect(NEASource().isConfigured)
    }
}

@Suite("OpenMeteoSource")
struct OpenMeteoSourceTests {

    @Test("returns readings parsed from the air quality endpoint")
    func returnsReadings() async throws {
        let source = OpenMeteoSource { _ in try Fixture.data("open_meteo") }

        let readings = try await source.fetchCurrent()

        #expect(readings.contains { $0.metric == .pm2_5 && $0.value == 21.9 })
        #expect(readings.allSatisfy { $0.source == .openMeteo })
    }

    @Test("asks for Singapore, hourly, in Singapore time")
    func requestsSingapore() async throws {
        let recorder = URLRecorder()
        let source = OpenMeteoSource { url in
            await recorder.record(url)
            return try Fixture.data("open_meteo")
        }

        _ = try await source.fetchCurrent()
        let url = try #require(await recorder.urls.first)

        #expect(url.contains("latitude=1.3521"))
        #expect(url.contains("longitude=103.8198"))
        #expect(url.contains("pm2_5"))
    }

    @Test("needs no API key")
    func needsNoKey() {
        #expect(OpenMeteoSource().isConfigured)
    }
}

private actor URLRecorder {
    private(set) var urls: [String] = []
    func record(_ url: URL) { urls.append(url.absoluteString) }
}
