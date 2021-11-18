import Foundation
import Storable

public protocol Cacheable: AnyObject {
    associatedtype Key
    associatedtype Value

    func insert(_ value: Value, forKey key: Key) async
    func value(forKey key: Key) async -> Value?
    func removeValue(forKey key: Key) async
}

public actor Cache<K: Hashable, V> {
    public typealias DateProvider = () -> Date
    public typealias Key = K
    public typealias Value = V

    private let wrapped = NSCache<WrappedKey, Entry>()
    private let keyTracker = KeyTracker()
    private let dateProvider: DateProvider
    private let entryLifetime: TimeInterval?

    public init(
        dateProvider: @escaping DateProvider = { Date() },
        entryLifetime: TimeInterval? = nil
    ) {
        self.dateProvider = dateProvider
        self.entryLifetime = entryLifetime

        wrapped.delegate = keyTracker
    }
}

extension Cache: Cacheable {
    public func insert(
        _ value: Value,
        forKey key: Key
    ) async {
        let date: Date?
        if let entryLifetime = entryLifetime {
            date = dateProvider().addingTimeInterval(entryLifetime)
        } else {
            date = nil
        }

        let entry = Entry(
            key: key,
            value: value,
            expirationDate: date
        )
        let wrappedKey = WrappedKey(key)
        wrapped.setObject(entry, forKey: wrappedKey)
        keyTracker.keys.insert(key)
    }

    public func value(forKey key: Key) async -> Value? {
        guard
            let entry = wrapped.object(forKey: WrappedKey(key))
        else {
            return nil
        }

        if let expirationDate = entry.expirationDate, dateProvider() >= expirationDate {
            await removeValue(forKey: key)

            return nil
        }

        return entry.value
    }

    public func removeValue(forKey key: Key) async {
        wrapped.removeObject(forKey: WrappedKey(key))
    }
}

extension Cache {
    final class WrappedKey: NSObject {
        init(_ key: Key) {
            self.key = key
        }

        let key: Key

        override var hash: Int { key.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            (object as? WrappedKey)?.key == key
        }
    }
}

extension Cache {
    final class Entry: Hashable {
        let key: Key
        let value: Value
        let expirationDate: Date?

        init(
            key: Key,
            value: Value,
            expirationDate: Date?
        ) {
            self.key = key
            self.value = value
            self.expirationDate = expirationDate
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Cache<K, V>.Entry, rhs: Cache<K, V>.Entry) -> Bool {
            lhs.key == rhs.key
        }
    }
}

extension Cache {
    final class KeyTracker: NSObject, NSCacheDelegate {
        var keys = Set<Key>()

        func cache(
            _ cache: NSCache<AnyObject, AnyObject>,
            willEvictObject object: Any
        ) {
            guard
                let entry = object as? Entry
            else {
                return
            }

            keys.remove(entry.key)
        }
    }
}

extension Cache.Entry: Codable where K: Codable, V: Codable {}

private extension Cache {
    func entry(forKey key: Key) async -> Entry? {
        guard
            let entry = wrapped.object(forKey: WrappedKey(key))
        else {
            return nil
        }

        if let expirationDate = entry.expirationDate,
           dateProvider() >= expirationDate {
            await removeValue(forKey: key)

            return nil
        }

        return entry
    }

    func insert(_ entry: Entry) async {
        wrapped.setObject(entry, forKey: WrappedKey(entry.key))
        keyTracker.keys.insert(entry.key)
    }
}

public extension Cache where Key: Codable, Value: Codable {
    func saveToDisk(
        to url: URL,
        using storage: Storable
    ) async throws {
        let keys = keyTracker.keys
        var entries = Set<Entry>()
        for key in keys {
            if let entry = await entry(forKey: key) {
                entries.insert(entry)
            }
        }

        let data = try JSONEncoder().encode(entries)

        try await storage.store(data, to: url)
    }

    static func readFrom(
        _ storage: Storable,
        with url: URL
    ) async throws -> Cache? {
        if let data = try await storage.load(from: url) {
            let cache = Cache<Key, Value>()

            let entries = try JSONDecoder().decode(Set<Entry>.self, from: data)

            for entrty in entries {
                await cache.insert(entrty)
            }

            return cache
        }

        return nil
    }
}
