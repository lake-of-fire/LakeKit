import Foundation
import KeychainSwift
import Security

enum SessionCredentialRead<Value> {
    case value(Value)
    case missing
    case unavailable

    func resolved() throws -> Value? {
        switch self {
        case .value(let value): return value
        case .missing: return nil
        case .unavailable: throw SessionCredentialStorageError.unavailable
        }
    }
}

private enum SessionCredentialStorageError: Error {
    case unavailable
}

struct SessionCredentialStore {
    let data: (String) -> SessionCredentialRead<Data>
    let string: (String) -> SessionCredentialRead<String>
    let setData: (Data, String) -> Bool
    let setString: (String, String) -> Bool
    let delete: (String) -> Bool

    init(
        data: @escaping (String) -> SessionCredentialRead<Data>,
        string: @escaping (String) -> SessionCredentialRead<String>,
        setData: @escaping (Data, String) -> Bool,
        setString: @escaping (String, String) -> Bool,
        delete: @escaping (String) -> Bool
    ) {
        self.data = data
        self.string = string
        self.setData = setData
        self.setString = setString
        self.delete = delete
    }

    init(keychain: KeychainSwift) {
        data = {
            if let value = keychain.getData($0) { return .value(value) }
            return keychain.lastResultCode == errSecItemNotFound ? .missing : .unavailable
        }
        string = {
            if let value = keychain.get($0) { return .value(value) }
            return keychain.lastResultCode == errSecItemNotFound ? .missing : .unavailable
        }
        setData = {
            keychain.set(
                $0,
                forKey: $1,
                withAccess: .accessibleAfterFirstUnlock
            )
        }
        setString = {
            keychain.set(
                $0,
                forKey: $1,
                withAccess: .accessibleAfterFirstUnlock
            )
        }
        delete = {
            let deleted = keychain.delete($0)
            return deleted || keychain.lastResultCode == errSecItemNotFound
        }
    }
}

struct SessionCredentials: Codable, Equatable {
    let authToken: String
    let userID: Int
    let revision: UInt64
    let recordID: String

    init(
        authToken: String,
        userID: Int,
        revision: UInt64 = 0,
        recordID: String = UUID().uuidString
    ) {
        self.authToken = authToken
        self.userID = userID
        self.revision = revision
        self.recordID = recordID
    }

    private enum CodingKeys: String, CodingKey {
        case authToken
        case userID
        case revision
        case recordID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authToken = try container.decode(String.self, forKey: .authToken)
        userID = try container.decode(Int.self, forKey: .userID)
        revision = try container.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
        recordID = try container.decodeIfPresent(String.self, forKey: .recordID) ?? ""
    }

    var isValid: Bool {
        !authToken.isEmpty && userID >= 0
    }
}

/// Stores each complete account credential pair in alternating Keychain records.
/// KeychainSwift replaces values with delete-then-add, so a single-record write can
/// erase the previous login when the add fails. Alternating records preserve the
/// previous complete pair until a newer complete pair has been committed.
struct SessionCredentialRepository {
    private enum Key {
        static let canonicalPrimary = "accountCredentials.v1.primary"
        static let canonicalSecondary = "accountCredentials.v1.secondary"
        static let deprecatedCanonical = "accountCredentials.v1"
        static let legacyAuthToken = "authToken"
        static let legacyUserID = "userID"
    }

    private enum Slot: CaseIterable, Equatable {
        case primary
        case secondary

        var key: String {
            switch self {
            case .primary: Key.canonicalPrimary
            case .secondary: Key.canonicalSecondary
            }
        }

        var alternate: Slot {
            switch self {
            case .primary: .secondary
            case .secondary: .primary
            }
        }
    }

    private struct Record {
        let slot: Slot
        let credentials: SessionCredentials
    }

    private let store: SessionCredentialStore

    init(store: SessionCredentialStore) {
        self.store = store
    }

    func load() throws -> SessionCredentials? {
        if let record = try currentCanonicalRecord() {
            guard record.credentials.recordID.isEmpty else { return record.credentials }
            let upgraded = SessionCredentials(
                authToken: record.credentials.authToken,
                userID: record.credentials.userID,
                revision: record.credentials.revision
            )
            guard persistCanonical(upgraded) else { return record.credentials }
            return (try? currentCanonicalRecord())?.credentials ?? record.credentials
        }

        if let data = try store.data(Key.deprecatedCanonical).resolved() {
            if let credentials = decodeValidCredentials(data) {
                // Migration failure does not invalidate a complete existing login.
                if persistCanonical(credentials) {
                    return (try? currentCanonicalRecord())?.credentials ?? credentials
                }
                return credentials
            }
            _ = store.delete(Key.deprecatedCanonical)
        }

        let legacyAuthToken = try store.string(Key.legacyAuthToken).resolved()
        let legacyUserID = try store.string(Key.legacyUserID).resolved().flatMap(Int.init)
        guard let legacyAuthToken,
              !legacyAuthToken.isEmpty,
              let legacyUserID,
              legacyUserID >= 0 else {
            if legacyAuthToken != nil || legacyUserID != nil {
                _ = removeLegacyCredentials()
            }
            return nil
        }
        let credentials = SessionCredentials(
            authToken: legacyAuthToken,
            userID: legacyUserID
        )
        if persistCanonical(credentials), let persisted = (try? currentCanonicalRecord())?.credentials {
            return persisted
        }
        // A failed write or unavailable readback must not invalidate the complete
        // legacy login. Publish durable identity only after canonical readback.
        return SessionCredentials(
            authToken: legacyAuthToken,
            userID: legacyUserID,
            recordID: ""
        )
    }

    func persist(_ credentials: SessionCredentials) -> Bool {
        guard persistCanonical(credentials) else { return false }
        // These mirrors support older app versions but are never read when a
        // canonical record exists.
        _ = store.setString(credentials.authToken, Key.legacyAuthToken)
        _ = store.setString(String(credentials.userID), Key.legacyUserID)
        return true
    }

    func remove() -> Bool {
        // Determine the current slot before any destructive operation. An
        // unreadable newer record must never make an older account authoritative.
        let currentRecord: Record?
        do { currentRecord = try currentCanonicalRecord() }
        catch { return false }
        var removedSupersededSlots = true
        for slot in Slot.allCases where slot != currentRecord?.slot {
            let removed = store.delete(slot.key)
            removedSupersededSlots = removed && removedSupersededSlots
        }
        let removedDeprecatedCanonical = store.delete(Key.deprecatedCanonical)
        let removedLegacy = removeLegacyCredentials()
        guard removedSupersededSlots, removedDeprecatedCanonical, removedLegacy else {
            // Preserve the newest complete login until all fallback records are gone.
            return false
        }
        guard let currentRecord else { return true }
        return store.delete(currentRecord.slot.key)
    }

    private func persistCanonical(_ credentials: SessionCredentials) -> Bool {
        guard credentials.isValid else { return false }
        let currentRecord: Record?
        do { currentRecord = try currentCanonicalRecord() }
        catch { return false }
        let currentRevision = currentRecord?.credentials.revision ?? 0
        guard currentRevision < UInt64.max else { return false }
        let revisedCredentials = SessionCredentials(
            authToken: credentials.authToken,
            userID: credentials.userID,
            revision: currentRevision + 1,
            recordID: credentials.recordID.isEmpty ? UUID().uuidString : credentials.recordID
        )
        guard let data = try? JSONEncoder().encode(revisedCredentials) else {
            return false
        }
        let destination = currentRecord?.slot.alternate ?? .primary
        guard store.setData(data, destination.key) else { return false }
        _ = store.delete(Key.deprecatedCanonical)
        return true
    }

    private func currentCanonicalRecord() throws -> Record? {
        var records = [Record]()
        records.reserveCapacity(Slot.allCases.count)
        // Read every slot before repairing malformed records. A failed read
        // leaves the whole durable credential set untouched.
        let values = try Slot.allCases.map { ($0, try store.data($0.key).resolved()) }
        for (slot, value) in values {
            guard let data = value else { continue }
            guard let credentials = decodeValidCredentials(data) else {
                _ = store.delete(slot.key)
                continue
            }
            records.append(Record(slot: slot, credentials: credentials))
        }
        return records.max { lhs, rhs in
            if lhs.credentials.revision != rhs.credentials.revision {
                return lhs.credentials.revision < rhs.credentials.revision
            }
            // Synchronizable keychains can receive equal revisions from two
            // devices. A stable tie-breaker keeps selection deterministic.
            return lhs.credentials.recordID < rhs.credentials.recordID
        }
    }

    private func decodeValidCredentials(_ data: Data) -> SessionCredentials? {
        guard let credentials = try? JSONDecoder().decode(
            SessionCredentials.self,
            from: data
        ), credentials.isValid else { return nil }
        return credentials
    }

    private func removeLegacyCredentials() -> Bool {
        // Deletion status, rather than an optional read, proves absence.
        let removedAuthToken = store.delete(Key.legacyAuthToken)
        let removedUserID = store.delete(Key.legacyUserID)
        return removedAuthToken && removedUserID
    }
}
