// Re-export the package while keeping its concrete backend out of app modules.
@_exported import PersistedLRUCache

/// Stable app-facing name for the persisted cache implementation.
public typealias PersistedCache<Input: Encodable, Output: Codable> =
    LRUSQLiteCache<Input, Output>
