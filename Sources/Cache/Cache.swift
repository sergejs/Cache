import Foundation
import Storable

public protocol Cacheable: AnyObject {
    associatedtype Key
    associatedtype Value

    func insert(_ value: Value, forKey key: Key)
    func value(forKey key: Key) -> Value?
    func removeValue(forKey key: Key)
}

public final class Cache<K: Hashable, V>: Cacheable {
    // MARK: Lifecycle

    public init(
        dateProvider: @escaping DateProvider = { Date() },
        entryLifetime: TimeInterval? = nil
    ) {
        self.dateProvider = dateProvider
        self.entryLifetime = entryLifetime

        wrapped.delegate = keyTracker
    }

    // MARK: Public

    public typealias DateProvider = () -> Date
    public typealias Key = K
    public typealias Value = V

    public func insert(
        _ value: Value,
        forKey key: Key
    ) {
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
        wrapped.setObject(entry, forKey: WrappedKey(key))
        keyTracker.keys.insert(key)
    }

    public func value(forKey key: Key) -> Value? {
        guard
            let entry = wrapped.object(forKey: WrappedKey(key))
        else {
            return nil
        }

        if let expirationDate = entry.expirationDate,
           dateProvider() >= expirationDate {
            removeValue(forKey: key)
            return nil
        }

        return entry.value
    }

    public func removeValue(forKey key: Key) {
        wrapped.removeObject(forKey: WrappedKey(key))
    }

    // MARK: Private

    private let wrapped = NSCache<WrappedKey, Entry>()
    private let dateProvider: DateProvider
    private let entryLifetime: TimeInterval?
    private let keyTracker = KeyTracker()
}

private extension Cache {
    final class WrappedKey: NSObject {
        // MARK: Lifecycle

        init(_ key: Key) {
            self.key = key
        }

        // MARK: Internal

        let key: Key

        override var hash: Int { key.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            guard
                let value = object as? WrappedKey
            else {
                return false
            }

            return value.key == key
        }
    }
}

private extension Cache {
    final class Entry {
        // MARK: Lifecycle

        init(
            key: Key,
            value: Value,
            expirationDate: Date?
        ) {
            self.key = key
            self.value = value
            self.expirationDate = expirationDate
        }

        // MARK: Internal

        let key: Key
        let value: Value
        let expirationDate: Date?
    }
}

private extension Cache {
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
    func entry(forKey key: Key) -> Entry? {
        guard
            let entry = wrapped.object(forKey: WrappedKey(key))
        else {
            return nil
        }

        if
            let expirationDate = entry.expirationDate,
            dateProvider() >= expirationDate {
            removeValue(forKey: key)
            return nil
        }

        return entry
    }

    func insert(_ entry: Entry) {
        wrapped.setObject(entry, forKey: WrappedKey(entry.key))
        keyTracker.keys.insert(entry.key)
    }
}

extension Cache: Codable where Key: Codable, Value: Codable {
    public convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.singleValueContainer()
        let entries = try container.decode([Entry].self)
        entries.forEach(insert)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(keyTracker.keys.compactMap(entry))
    }
}

public extension Cache where Key: Codable, Value: Codable {
    func saveToDisk(
        to url: URL,
        using storage: Storable
    ) async throws {
        let data = try JSONEncoder()
            .encode(self)

        try await storage.store(data, to: url)
    }

    static func readFrom(
        _ storage: Storable,
        with url: URL
    ) async throws -> Cache? {
        if let data = try await storage.load(from: url) {
            let cache = try JSONDecoder().decode(Cache.self, from: data)
            return cache
        }

        return nil
    }
}
