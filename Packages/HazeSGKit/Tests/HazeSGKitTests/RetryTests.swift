import Testing
import Foundation
@testable import HazeSGKit

private actor CallCounter {
    private(set) var count = 0
    func next() -> Int { count += 1; return count }
}

@Suite("Retrying on rate limits")
struct RetryTests {

    @Test("retries a 429 and succeeds on the next attempt")
    func retriesRateLimit() async throws {
        let counter = CallCounter()
        let fetch = retrying(delay: 0) { _ in
            let attempt = await counter.next()
            if attempt == 1 { throw SourceError.badStatus(429) }
            return Data("ok".utf8)
        }

        let data = try await fetch(URL(string: "https://example.com")!)

        #expect(String(decoding: data, as: UTF8.self) == "ok")
        #expect(await counter.count == 2)
    }

    @Test("gives up after the retry budget rather than hammering")
    func stopsRetrying() async {
        // data.gov.sg rate-limits per 10 seconds. Retrying forever would
        // keep the limit tripped and drain the battery doing it.
        let counter = CallCounter()
        let fetch = retrying(attempts: 3, delay: 0) { _ in
            _ = await counter.next()
            throw SourceError.badStatus(429)
        }

        await #expect(throws: SourceError.badStatus(429)) {
            try await fetch(URL(string: "https://example.com")!)
        }
        #expect(await counter.count == 3)
    }

    @Test("does not retry a 404, which will not fix itself")
    func doesNotRetryPermanentFailures() async {
        let counter = CallCounter()
        let fetch = retrying(delay: 0) { _ in
            _ = await counter.next()
            throw SourceError.badStatus(404)
        }

        await #expect(throws: SourceError.badStatus(404)) {
            try await fetch(URL(string: "https://example.com")!)
        }
        #expect(await counter.count == 1)
    }
}
