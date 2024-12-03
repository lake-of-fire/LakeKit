import Foundation

public extension Bundle {
    var appVersionLong: String    { getInfo("CFBundleShortVersionString") }
    var appBuild: String          { getInfo("CFBundleVersion") }
    
    var versionString: String {
        return appVersionLong + "-" + appBuild
    }
    
    private func getInfo(_ str: String) -> String {
        infoDictionary?[str] as? String ?? "UNKNOWN-VERSION"
    }
}
