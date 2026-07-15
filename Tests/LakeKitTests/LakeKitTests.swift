import XCTest
@testable import LakeKit

final class LakeKitPersistedLRUCacheDependencyTests: XCTestCase {
    func testPersistedCacheStoresAndReloadsValues() throws {
        let root = try makeTemporaryRoot()
        let namespace = "lakekit.persisted.\(UUID().uuidString)"

        let cache = PersistedLRUCache<String, String>(
            namespace: namespace,
            inlineStorageThreshold: 8,
            compressionThreshold: .max,
            cacheRootURL: root
        )
        cache.setValue(String(repeating: "value", count: 8), forKey: "key")

        XCTAssertEqual(cache.value(forKey: "key"), String(repeating: "value", count: 8))
        XCTAssertEqual(
            PersistedLRUCache<String, String>(
                namespace: namespace,
                inlineStorageThreshold: 8,
                compressionThreshold: .max,
                cacheRootURL: root
            ).value(forKey: "key"),
            String(repeating: "value", count: 8)
        )
    }

    func testSQLiteCacheStoresAndReloadsValues() throws {
        let root = try makeTemporaryRoot()
        let namespace = "lakekit.sqlite.\(UUID().uuidString)"

        let cache = LRUSQLiteCache<String, String>(namespace: namespace, cacheRootURL: root)
        cache.setValue("value", forKey: "key")

        XCTAssertEqual(cache.value(forKey: "key"), "value")
        XCTAssertEqual(
            LRUSQLiteCache<String, String>(namespace: namespace, cacheRootURL: root).value(forKey: "key"),
            "value"
        )
    }

    func testFileCacheStoresAndReloadsValues() throws {
        let root = try makeTemporaryRoot()
        let namespace = "lakekit.file.\(UUID().uuidString)"

        let cache = LRUFileCache<String, String>(namespace: namespace, cacheRootURL: root)
        cache.setValue("value", forKey: "key")

        XCTAssertEqual(cache.value(forKey: "key"), "value")
        XCTAssertEqual(
            LRUFileCache<String, String>(namespace: namespace, cacheRootURL: root).value(forKey: "key"),
            "value"
        )
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("LakeKitPersistedLRUCacheDependencyTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
