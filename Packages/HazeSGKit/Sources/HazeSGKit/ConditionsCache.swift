import Foundation

/// Somewhere to keep the last good reading between widget refreshes.
public protocol CacheStore: Sendable {
    func read() -> Data?
    func write(_ data: Data)
}

/// `UserDefaults` inside the process's own container.
///
/// Deliberately not an App Group: sharing a cache between the app and the
/// widget needs one, App Groups require a paid developer account, and the
/// widget keeping its own copy is enough to stop it showing "No reading"
/// when a fetch fails.
/// `UserDefaults` is not `Sendable`, but it is documented as thread-safe,
/// so the suite name is stored instead of the instance.
public struct UserDefaultsStore: CacheStore {
    private let key: String
    private let suiteName: String?

    public init(key: String = "cachedConditions", suiteName: String? = nil) {
        self.key = key
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func read() -> Data? { defaults.data(forKey: key) }
    public func write(_ data: Data) { defaults.set(data, forKey: key) }
}

/// Last known conditions per region.
///
/// A stale reading with its age shown is far more useful than an empty
/// widget. Air quality does not change so fast that an hour-old number is
/// worthless, and "no reading" tells you nothing at all.
public struct ConditionsCache: Sendable {
    private let store: any CacheStore

    public init(store: any CacheStore = UserDefaultsStore()) {
        self.store = store
    }

    public func load(for region: Region) -> Conditions? {
        all()[region.rawValue]
    }

    public func save(_ conditions: Conditions) {
        var current = all()
        current[conditions.region.rawValue] = conditions
        guard let data = try? JSONEncoder().encode(current) else { return }
        store.write(data)
    }

    /// Returns an empty map rather than throwing on a corrupt store — a
    /// widget that crashes shows a blank rectangle forever.
    private func all() -> [String: Conditions] {
        guard let data = store.read(),
              let decoded = try? JSONDecoder().decode([String: Conditions].self, from: data)
        else { return [:] }
        return decoded
    }
}
