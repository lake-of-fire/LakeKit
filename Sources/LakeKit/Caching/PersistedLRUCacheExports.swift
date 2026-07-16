// LakeKit's SwiftPM and Tuist graphs both alias this implementation target to
// the public PersistedLRUCache module name for downstream consumers.
@_exported import PersistedLRUCacheHybrid

/// Stable app-facing name for the SQLite-backed persisted cache implementation.
public typealias PersistedCache<Input: Encodable, Output: Codable> =
    LRUSQLiteCache<Input, Output>
