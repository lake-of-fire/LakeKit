import SwiftUI
import KeychainSwift
import BetterSafariView

public class Session: ObservableObject {
    public var keychain: KeychainSwift?
    @MainActor @Published public var isPresentingWebAuthentication = false
    @Published public var userID: Int?
    
    @MainActor private var authenticationContinuations = [CheckedContinuation<Void, Error>]()
    
    public var isAuthenticated: Bool {
        guard let keychain = keychain else { return false }
        return !(keychain.get("authToken") ?? "").isEmpty && !(keychain.get("userID") ?? "").isEmpty
    }
    
    public init(keychain: KeychainSwift) {
        self.keychain = keychain
        Task { @MainActor in
            if let userIDString = keychain.get("userID"), let userID = Int(userIDString) {
                self.userID = userID
            } else {
                logout()
            }
        }
    }
    
    public func requireAuthentication() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                if isAuthenticated {
                    continuation.resume()
                    return
                }
                authenticationContinuations.append(continuation)
                if !isPresentingWebAuthentication {
                    isPresentingWebAuthentication = true
                }
            }
        }
    }
    
    public func authenticated(authToken: String, userID: Int) {
        keychain?.set(authToken, forKey: "authToken")
        keychain?.set(String(userID), forKey: "userID")
        
        Task { @MainActor in
            self.userID = userID
            
            for continuation in authenticationContinuations {
                continuation.resume()
            }
            authenticationContinuations.removeAll()
        }
    }
    
    public func cancelAuthentication(error: Error? = nil) {
        Task { @MainActor in
            logout()
            for continuation in authenticationContinuations {
                continuation.resume(throwing: error ?? SessionError.notAuthenticatedAsRequired)
            }
            authenticationContinuations.removeAll()
        }
    }
    
    public func logout() {
        keychain?.delete("authToken")
        keychain?.delete("userID")
        Task { @MainActor in
            userID = nil
        }
    }
}

public enum SessionError: Error {
    case notAuthenticatedAsRequired
}


public extension View {
    func lakeAuthenticationSession(session: Session) -> some View {
        self.modifier(LakeAuthenticationSessionModifier(session: session))
    }
}

public struct LakeAuthenticationSessionModifier: ViewModifier {
    @MainActor @StateObject public var session: Session

    public func body(content: Content) -> some View {
        content
            .webAuthenticationSession(isPresented: $session.isPresentingWebAuthentication) {
                WebAuthenticationSession(url: URL(string: "https://manabi.io/accounts/login/?next=/accounts/native-app-login-redirect/manabireader/")!, callbackURLScheme: "manabireader") { callbackURL, error in
                    if let error = error {
                        print(error)
                        if !session.isAuthenticated {
                            session.cancelAuthentication(error: error)
                        }
                        return
                    }
                    guard let callbackURL = callbackURL, let components = NSURLComponents(url: callbackURL, resolvingAgainstBaseURL: true), let scheme = components.scheme, scheme == "manabireader", let host = components.host else {
                        print("Invalid URL \(callbackURL?.absoluteString ?? "(unknown URL)")")
                        session.cancelAuthentication()
                        return
                    }
                    if host == "login-success" || host == "signup-success", let queryItems = components.queryItems {
                        var foundAuthToken: String?, foundUserID: Int?
                        for queryItem in queryItems {
                            if queryItem.name == "authToken", let authToken = queryItem.value, !authToken.isEmpty {
                                foundAuthToken = authToken
                            } else if queryItem.name == "userID", let userIDString = queryItem.value, let userID = Int(userIDString) {
                                foundUserID = userID
                            }
                        }
                        if let authToken = foundAuthToken, let userID = foundUserID {
                            session.authenticated(authToken: authToken, userID: userID)
                            return
                        }
                    }
                    session.cancelAuthentication()
                }
                .prefersEphemeralWebBrowserSession(true)
            }
    }
}


