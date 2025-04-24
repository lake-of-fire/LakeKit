import Foundation
import RealmSwift
import RealmSwiftGaps
import BigSyncKit
import SwiftUtilities

public class ReferralCodeUsage: Object, UnownedSyncableObject, ChangeMetadataRecordable {
    @Persisted(primaryKey: true) public var id = UUID()
    
    @Persisted public var explicitlyModifiedAt: Date?
    @Persisted public var createdAt = Date()
    @Persisted public var modifiedAt = Date()
    @Persisted public var isDeleted = false
    
    @Persisted public var referralCode: String = ""
    @Persisted public var itunesReceipt: String = ""
    @Persisted public var originalTransactionId: String = ""
    @Persisted public var wasSubmitted: Bool = false
    @Persisted public var lastAttemptedAt: Date?
    
    public var needsSyncToAppServer: Bool {
        return false
    }
    
    @RealmBackgroundActor
    public static func create(referralCode: String, receipt: String, realmConfiguration: Realm.Configuration) async throws -> ReferralCodeUsage {
        let realm = try await RealmBackgroundActor.shared.cachedRealm(for: realmConfiguration)
        let usage = ReferralCodeUsage()
        usage.referralCode = referralCode
        usage.itunesReceipt = receipt
        usage.wasSubmitted = false
        usage.lastAttemptedAt = nil
        usage.createdAt = Date()
        usage.modifiedAt = Date()
//        await realm.asyncRefresh()
        try await realm.asyncWrite {
            realm.add(usage, update: .modified)
        }
        return usage
    }
}
