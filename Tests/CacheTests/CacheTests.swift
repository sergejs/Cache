//
//  CacheTests.swift
//
//
//  Created by Sergejs Smirnovs on 09.11.21.
//

@testable import Cache
import Storable
import XCTest

final class CacheTests: XCTestCase {
    var sut: Cache<String, Data>?

    func testReadWriteSuccess() {
        self.sut = Cache<String, Data>()
        let sut = sut!
        let data = "Data".data(using: .utf8)!

        sut.insert(data, forKey: "key")
        let storedData = sut.value(forKey: "key")

        XCTAssertEqual(storedData, data)
    }

    func testReadWriteRemoveSuccess() {
        self.sut = Cache<String, Data>()
        let sut = sut!
        let data = "Data".data(using: .utf8)!
        var storedData: Data?

        sut.insert(data, forKey: "key")
        storedData = sut.value(forKey: "key")
        XCTAssertEqual(storedData, data)

        sut.removeValue(forKey: "key")
        storedData = sut.value(forKey: "key")
        XCTAssertNil(storedData)
    }

    func testSaveLoadStorageSuccess() async {
        let storage = MemoryStorage()
        sut = Cache<String, Data>(
            entryLifetime: 60 * 60 * 24 * 31
        )
        let sut = sut!
        let data = "Data".data(using: .utf8)!
        var storedData: Data?
        sut.insert(data, forKey: "key")
        storedData = sut.value(forKey: "key")
        XCTAssertEqual(storedData, data)

        do {
            try await sut.saveToDisk(
                to: URL(string: "MEM")!,
                using: storage
            )
        } catch {
            XCTFail("Unexpected error")
        }

        var loadedCache: Cache<String, Data>?
        do {
            loadedCache = try await Cache<String, Data>
                .readFrom(
                    storage,
                    with: URL(string: "MEM")!
                )
        } catch {
            XCTFail("Unexpected error")
        }
        storedData = loadedCache?.value(forKey: "key")
        XCTAssertEqual(storedData, data)
    }

    func testLifeTimeSuccess() {
        self.sut = Cache<String, Data>(
            entryLifetime: 60 * 60 * 24 * 31
        )
        let sut = sut!
        let data = "Data".data(using: .utf8)!
        var storedData: Data?
        sut.insert(data, forKey: "key")
        storedData = sut.value(forKey: "key")

        XCTAssertEqual(storedData, data)
    }

    func testLifeTimeTimemout() {
        var firstDate = true
        let dateProvider: Cache.DateProvider = {
            if firstDate {
                firstDate = false
                return Date()
            }
            return Date() + 60 * 60 * 24 * 31 + 1
        }

        self.sut = Cache<String, Data>(
            dateProvider: dateProvider,
            entryLifetime: 60 * 60 * 24 * 31
        )
        let sut = sut!
        let data = "Data".data(using: .utf8)!
        var storedData: Data?
        sut.insert(data, forKey: "key")
        storedData = sut.value(forKey: "key")
        XCTAssertNil(storedData)
    }

    func testInvalidatedKeyAfterLoading() async {
        enum Step {
            case save, secondSave, read, restore
        }
        var step: Step = .save
        let dateProvider: Cache.DateProvider = {
            switch step {
                case .save:
                    return Date()
                case .secondSave:
                    return Date() + 10
                case .read:
                    return Date()
                case .restore:
                    return Date() + 60 + 1
            }
        }

        let storage = MemoryStorage()
        let sut = Cache<String, Data>(
            dateProvider: dateProvider,
            entryLifetime: 60
        )

        let data1 = "Data1".data(using: .utf8)!
        let data2 = "Data2".data(using: .utf8)!
        var storedData1: Data?
        var storedData2: Data?

        sut.insert(data1, forKey: "key")

        step = .secondSave
        sut.insert(data2, forKey: "key2")

        step = .read
        storedData1 = sut.value(forKey: "key")
        storedData2 = sut.value(forKey: "key2")

        XCTAssertEqual(storedData1, data1)
        XCTAssertEqual(storedData2, data2)

        step = .restore

        do {
            try await sut.saveToDisk(
                to: URL(string: "MEM")!,
                using: storage
            )
        } catch {
            XCTFail("Unexpected error")
        }

        var loadedCache: Cache<String, Data>?
        do {
            loadedCache = try await Cache<String, Data>
                .readFrom(
                    storage,
                    with: URL(string: "MEM")!
                )
        } catch {}
        storedData1 = loadedCache?.value(forKey: "key")
        storedData2 = loadedCache?.value(forKey: "key2")

        XCTAssertNil(storedData1)
        XCTAssertEqual(storedData2, data2)
    }
}
