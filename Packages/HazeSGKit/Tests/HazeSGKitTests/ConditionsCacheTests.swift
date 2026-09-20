import Testing
import Foundation
@testable import HazeSGKit

private final class MemoryStore: CacheStore, @unchecked Sendable {
    var stored: Data?
    func read() -> Data? { stored }
    func write(_ data: Data) { stored = data }
}

private let at = Date(timeIntervalSince1970: 1_789_884_000)

private let conditions = Conditions(
    region: .central, pm25: 36, psi: 104, observedAt: at
)

@Suite("ConditionsCache")
struct ConditionsCacheTests {

    @Test("returns what was last saved for that region")
    func roundTrips() {
        let cache = ConditionsCache(store: MemoryStore())
        cache.save(conditions)

        #expect(cache.load(for: .central) == conditions)
    }

    @Test("does not hand back another region's reading")
    func regionSpecific() {
        // Showing Central's number under a North heading would be worse
        // than showing nothing.
        let cache = ConditionsCache(store: MemoryStore())
        cache.save(conditions)

        #expect(cache.load(for: .north) == nil)
    }

    @Test("keeps a reading per region rather than only the most recent")
    func keepsEachRegion() {
        let cache = ConditionsCache(store: MemoryStore())
        cache.save(conditions)
        cache.save(Conditions(region: .north, pm25: 19, psi: 75, observedAt: at))

        #expect(cache.load(for: .central)?.pm25 == 36)
        #expect(cache.load(for: .north)?.pm25 == 19)
    }

    @Test("returns nothing when the cache is empty")
    func emptyCache() {
        #expect(ConditionsCache(store: MemoryStore()).load(for: .central) == nil)
    }

    @Test("survives a corrupt store instead of crashing the widget")
    func toleratesGarbage() {
        // A widget that crashes shows a blank rectangle forever.
        let store = MemoryStore()
        store.stored = Data("not json".utf8)

        #expect(ConditionsCache(store: store).load(for: .central) == nil)
    }
}
