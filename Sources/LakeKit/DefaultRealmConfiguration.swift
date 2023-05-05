import Foundation
import RealmSwift

public enum DefaultRealmConfiguration {
    public static let schemaVersion: UInt64 = 47
    
    public static var configuration: Realm.Configuration {
        var config = Realm.Configuration.defaultConfiguration
        config.schemaVersion = schemaVersion
        config.migrationBlock = migrationBlock
        config.shouldCompactOnLaunch = { totalBytes, usedBytes in
            // totalBytes refers to the size of the file on disk in bytes (data + free space)
            // usedBytes refers to the number of bytes used by data in the file
            
            // Compact if the file is over size and less than some % 'used'
            let targetBytes = 40 * 1024 * 1024
            return (totalBytes > targetBytes) && (Double(usedBytes) / Double(totalBytes)) < 0.6
        }
        config.objectTypes = [
            FeedCategory.self,
            Feed.self,
            FeedEntry.self,
//            LibraryConfiguration.self,
//            UserScript.self,
//            UserScriptAllowedDomain.self,
        ]
        return config
    }

    public static func migrationBlock(migration: Migration, oldSchemaVersion: UInt64) {
        if oldSchemaVersion < schemaVersion {
            if oldSchemaVersion < 32 {
                migration.deleteData(forType: FeedEntry.className())
            }
        }
    }
}
