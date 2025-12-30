import XCTest
@testable import LakeKit

final class LRUSQLiteCacheTests: XCTestCase {
    // MARK: - Helpers
    func eventually(timeout: TimeInterval = 3.0, interval: TimeInterval = 0.05, file: StaticString = #filePath, line: UInt = #line, _ condition: @escaping () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(interval))
        }
        XCTFail("Condition not met within timeout", file: file, line: line)
    }
    
    func cleanup<K, V>(_ cache: LRUSQLiteCache<K, V>) {
        try? FileManager.default.removeItem(at: cache.cacheDirectory)
    }
    
    // MARK: - Basic String
    func testStringRawAndCompressedRoundTrip() {
        let ns = "test.strings.\(UUID().uuidString)"
        let cache = LRUSQLiteCache<String, String>(namespace: ns)
        defer { cleanup(cache) }
        
        let smallKey = "k1"
        let smallVal = "hello"
        cache.setValue(smallVal, forKey: smallKey)
        XCTAssertEqual(cache.value(forKey: smallKey), smallVal)
        
        let largeKey = "k2"
        let largeVal = String(repeating: "a", count: 220_000)
        cache.setValue(largeVal, forKey: largeKey)
        XCTAssertEqual(cache.value(forKey: largeKey), largeVal)
        
        // New instance should rebuild from SQLite-backed cache.
        let cache2 = LRUSQLiteCache<String, String>(namespace: ns)
        eventually {
            cache2.value(forKey: smallKey) == smallVal && cache2.value(forKey: largeKey) == largeVal
        }
        cleanup(cache2)
    }
    
    // MARK: - Data raw & compressed
    func testDataRawAndCompressedRoundTrip() {
        let ns = "test.data.\(UUID().uuidString)"
        let cache = LRUSQLiteCache<String, Data>(namespace: ns)
        defer { cleanup(cache) }
        
        let smallKey = "d1"
        let small = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        cache.setValue(small, forKey: smallKey)
        XCTAssertEqual(cache.value(forKey: smallKey), small)
        
        let largeKey = "d2"
        let large = Data(repeating: 0x42, count: 250_000)
        cache.setValue(large, forKey: largeKey)
        XCTAssertEqual(cache.value(forKey: largeKey), large)
        
        let cache2 = LRUSQLiteCache<String, Data>(namespace: ns)
        eventually { cache2.value(forKey: smallKey) == small && cache2.value(forKey: largeKey) == large }
        cleanup(cache2)
    }
    
    // MARK: - [UInt8] raw & compressed
    func testUInt8ArrayRawAndCompressedRoundTrip() {
        let ns = "test.uint8.\(UUID().uuidString)"
        let cache = LRUSQLiteCache<String, [UInt8]>(namespace: ns)
        defer { cleanup(cache) }
        
        let smallKey = "u1"
        let small: [UInt8] = Array(0..<32)
        cache.setValue(small, forKey: smallKey)
        XCTAssertEqual(cache.value(forKey: smallKey) ?? [], small)
        
        let largeKey = "u2"
        let large: [UInt8] = Array(repeating: 7, count: 230_000)
        cache.setValue(large, forKey: largeKey)
        XCTAssertEqual(cache.value(forKey: largeKey) ?? [], large)
        
        let cache2 = LRUSQLiteCache<String, [UInt8]>(namespace: ns)
        eventually { cache2.value(forKey: smallKey) == small && cache2.value(forKey: largeKey) == large }
        cleanup(cache2)
    }
    
    // MARK: - Codable JSON raw & compressed
    struct BigBlob: Codable, Equatable { let message: String; let numbers: [Int] }
    
    func testCodableRawAndCompressedRoundTrip() {
        let ns = "test.codable.\(UUID().uuidString)"
        let cache = LRUSQLiteCache<String, BigBlob>(namespace: ns)
        defer { cleanup(cache) }
        
        let smallKey = "c1"
        let small = BigBlob(message: "hi", numbers: [1,2,3])
        cache.setValue(small, forKey: smallKey)
        XCTAssertEqual(cache.value(forKey: smallKey), small)
        
        let largeKey = "c2"
        let large = BigBlob(message: String(repeating: "x", count: 240_000), numbers: Array(0..<10))
        cache.setValue(large, forKey: largeKey)
        XCTAssertEqual(cache.value(forKey: largeKey), large)
        
        let cache2 = LRUSQLiteCache<String, BigBlob>(namespace: ns)
        eventually { cache2.value(forKey: smallKey) == small && cache2.value(forKey: largeKey) == large }
        cleanup(cache2)
    }
    
    // MARK: - Remove single & remove all
    func testRemoveValueAndRemoveAll() {
        let ns = "test.remove.\(UUID().uuidString)"
        let cache = LRUSQLiteCache<String, String>(namespace: ns)
        defer { cleanup(cache) }
        
        cache.setValue("A", forKey: "a")
        cache.setValue("B", forKey: "b")
        XCTAssertEqual(cache.value(forKey: "a"), "A")
        XCTAssertEqual(cache.value(forKey: "b"), "B")
        
        cache.removeValue(forKey: "a")
        let cache2 = LRUSQLiteCache<String, String>(namespace: ns)
        eventually { cache2.value(forKey: "a") == nil && cache2.value(forKey: "b") == "B" }
        
        cache2.removeAll()
        let cache3 = LRUSQLiteCache<String, String>(namespace: ns)
        eventually { cache3.value(forKey: "a") == nil && cache3.value(forKey: "b") == nil }
        cleanup(cache2)
        cleanup(cache3)
    }
    
    // MARK: - LRU behavior by count limit
    func testLRUEvictionByCount() {
        let ns = "test.lru.count.\(UUID().uuidString)"
        let cache = LRUSQLiteCache<String, String>(namespace: ns, totalBytesLimit: .max, countLimit: 2)
        defer { cleanup(cache) }
        
        cache.setValue("1", forKey: "k1")
        cache.setValue("2", forKey: "k2")
        cache.setValue("3", forKey: "k3")
        
        // Expect first inserted to be evicted by count limit
        XCTAssertNil(cache.value(forKey: "k1"))
        XCTAssertEqual(cache.value(forKey: "k2"), "2")
        XCTAssertEqual(cache.value(forKey: "k3"), "3")
    }
    
    // MARK: - Nil value roundtrip (stored as tombstone)
    func testNilValueRoundTrip() {
        let ns = "test.nil.\(UUID().uuidString)"
        let cache = LRUSQLiteCache<String, String>(namespace: ns)
        defer { cleanup(cache) }
        
        cache.setValue(nil, forKey: "gone")
        XCTAssertNil(cache.value(forKey: "gone"))
        
        let cache2 = LRUSQLiteCache<String, String>(namespace: ns)
        eventually { cache2.value(forKey: "gone") == nil }
        cleanup(cache2)
    }
    
    // MARK: - Version bump clears store
    func testVersionBumpClearsStore() {
        let ns = "test.version.\(UUID().uuidString)"
        let cacheV1 = LRUSQLiteCache<String, String>(namespace: ns, version: 1)
        defer { cleanup(cacheV1) }
        cacheV1.setValue("persist", forKey: "k")
        
        let cacheV2 = LRUSQLiteCache<String, String>(namespace: ns, version: 2)
        // Expect store to be cleared during init when version changes
        eventually { cacheV2.value(forKey: "k") == nil }
        cleanup(cacheV2)
    }
    
    func testEvictionDeletesSQLiteRow() {
        let ns = "test.evict.sqlite.delete.\(UUID().uuidString)"
        let cache = LRUSQLiteCache<String, String>(namespace: ns, totalBytesLimit: .max, countLimit: 2)
        cache.setValue("1", forKey: "k1")
        cache.setValue("2", forKey: "k2")
        XCTAssertTrue(cache.containsKey("k1"))
        XCTAssertTrue(cache.containsKey("k2"))
        cache.setValue("3", forKey: "k3") // should evict k1 from memory and delete it from disk
        XCTAssertNil(cache.value(forKey: "k1"))
        XCTAssertFalse(cache.containsKey("k1"))
        XCTAssertEqual(cache.value(forKey: "k2"), "2")
        XCTAssertEqual(cache.value(forKey: "k3"), "3")
        
        let cache2 = LRUSQLiteCache<String, String>(namespace: ns)
        XCTAssertNil(cache2.value(forKey: "k1"))
        XCTAssertFalse(cache2.containsKey("k1"))
    }
    
    func testPresenceAPINoRowAfterEviction() {
        let ns = "test.presence.delete.\(UUID().uuidString)"
        let cache = LRUSQLiteCache<String, String>(namespace: ns, totalBytesLimit: .max, countLimit: 1)
        cache.setValue("A", forKey: "a")
        cache.setValue("B", forKey: "b") // evicts "a" and deletes sqlite row
        XCTAssertNil(cache.value(forKey: "a"))
        XCTAssertFalse(cache.containsKey("a"))
        XCTAssertEqual(cache.value(forKey: "b"), "B")
    }
}
