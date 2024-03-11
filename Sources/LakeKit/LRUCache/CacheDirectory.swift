//
//  CacheDirectory.swift
//  Stinkbug
//
//  Created by Richard Aurbach on 12/15/23.
//

import Foundation

class CacheDirectory {
	
	static public func folder() -> URL {
		do {
			let systemCacheFolder = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			let bundleID = Bundle.main.bundleIdentifier ?? appName
			let localCacheDirectory = systemCacheFolder.appendingPathComponent(bundleID, isDirectory: true)
			if !FileManager.default.fileExists(atPath: localCacheDirectory.path) {
				try FileManager.default.createDirectory(at: localCacheDirectory, withIntermediateDirectories: true, attributes: nil)
			}
			return localCacheDirectory
		} catch {
			fatalError("Failed to create private cache folder")
		}
	}
	
	static public func subFolder(name: String) -> URL {
		do {
			let url = folder().appendingPathComponent(name, isDirectory: true)
			if !FileManager.default.fileExists(atPath: url.path) {
				try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
			}
			return url
		} catch {
			fatalError("Failed to create private cache sub-folder")
		}
	}
	
	static private var appName: String {
		return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "<?>"
	}
}
