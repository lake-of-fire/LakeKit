import Foundation
import KeychainSwift

struct SessionCredentialStore {
    let data: (String) -> Data?
    let string: (String) -> String?
    let setData: (Data, String) -> Bool
    let setString: (String, String) -> Bool
    let delete: (String) -> Bool

    init(
        data: @escaping (String) -> Data?,
        string: @escaping (String) -> String?,
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
        data = { keychain.getData($0) }
        string = { keychain.get($0) }
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
        delete = { keychain.delete($0) }
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

    func load() -> SessionCredentials? {
        if let record = currentCanonicalRecord() {
            return record.credentials
        }

        if let data = store.data(Key.deprecatedCanonical) {
            if let credentials = decodeValidCredentials(data) {
                // Migration failure does not invalidate a complete existing login.
                _ = persistCanonical(credentials)
                return credentials
            }
            _ = deleteIfPresent(Key.deprecatedCanonical, exists: true)
        }

        let legacyAuthToken = store.string(Key.legacyAuthToken)
        let legacyUserID = store.string(Key.legacyUserID).flatMap(Int.init)
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
        _ = persistCanonical(credentials)
        return credentials
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
        let currentRecord = currentCanonicalRecord()
        var removedSupersededSlots = true
        for slot in Slot.allCases where slot != currentRecord?.slot {
            let removed = deleteIfPresent(
                slot.key,
                exists: store.data(slot.key) != nil
            )
            removedSupersededSlots = removed && removedSupersededSlots
        }
        let removedDeprecatedCanonical = deleteIfPresent(
            Key.deprecatedCanonical,
            exists: store.data(Key.deprecatedCanonical) != nil
        )
        let removedLegacy = removeLegacyCredentials()
        guard removedSupersededSlots,
              removedDeprecatedCanonical,
              removedLegacy else {
            // Keep the current complete pair when ancillary cleanup fails. This
            // avoids falling back to a superseded account on this or the next launch.
            return false
        }
        guard let currentRecord else { return true }
        return deleteIfPresent(
            currentRecord.slot.key,
            exists: store.data(currentRecord.slot.key) != nil
        )
    }

    private func persistCanonical(_ credentials: SessionCredentials) -> Bool {
        guard credentials.isValid else { return false }
        let currentRecord = currentCanonicalRecord()
        let currentRevision = currentRecord?.credentials.revision ?? 0
        guard currentRevision < UInt64.max else { return false }
        let revisedCredentials = SessionCredentials(
            authToken: credentials.authToken,
            userID: credentials.userID,
            revision: currentRevision + 1
        )
        guard let data = try? JSONEncoder().encode(revisedCredentials) else {
            return false
        }
        let destination = currentRecord?.slot.alternate ?? .primary
        guard store.setData(data, destination.key) else { return false }
        _ = deleteIfPresent(
            Key.deprecatedCanonical,
            exists: store.data(Key.deprecatedCanonical) != nil
        )
        return true
    }

    private func currentCanonicalRecord() -> Record? {
        var records = [Record]()
        records.reserveCapacity(Slot.allCases.count)
        for slot in Slot.allCases {
            guard let data = store.data(slot.key) else { continue }
            guard let credentials = decodeValidCredentials(data) else {
                _ = deleteIfPresent(slot.key, exists: true)
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
        let authTokenExists = store.string(Key.legacyAuthToken) != nil
        let userIDExists = store.string(Key.legacyUserID) != nil
        let removedAuthToken = deleteIfPresent(
            Key.legacyAuthToken,
            exists: authTokenExists
        )
        let removedUserID = deleteIfPresent(
            Key.legacyUserID,
            exists: userIDExists
        )
        return removedAuthToken && removedUserID
    }

    private func deleteIfPresent(_ key: String, exists: Bool) -> Bool {
        !exists || store.delete(key)
    }
}
