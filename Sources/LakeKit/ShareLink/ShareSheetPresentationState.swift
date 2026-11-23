import Foundation

/// A snapshot of presentation ownership, never a second live Binding. A new
/// request waits for the previous native controller's dismissal to complete.
struct ShareSheetPresentationState {
    struct Token: Equatable, Sendable {
        let requestID: UUID
        let generation: UUID
    }
    enum Action: Equatable {
        case none
        case present(Token)
        case dismiss(Token)
    }

    private(set) var current: Token?
    private(set) var isDismissing = false

    mutating func update(requestID: UUID?, hostIsReady: Bool) -> Action {
        guard !isDismissing else { return .none }
        if let current {
            guard current.requestID != requestID || !hostIsReady else { return .none }
            isDismissing = true
            return .dismiss(current)
        }
        guard hostIsReady, let requestID else { return .none }
        let token = Token(requestID: requestID, generation: UUID())
        current = token
        return .present(token)
    }

    func owns(_ token: Token, requestID: UUID?) -> Bool {
        !isDismissing && current == token && requestID == token.requestID
    }

    /// Only the matching native completion can clear the request it presented.
    /// Check the *current* binding ID as well: a successor may have been written
    /// before SwiftUI delivers updateNSView/updateUIViewController.
    mutating func completed(_ token: Token, requestID: UUID?) -> Bool {
        guard current == token, !isDismissing else { return false }
        current = nil
        return requestID == token.requestID
    }

    @discardableResult
    mutating func didDismiss(_ token: Token) -> Bool {
        guard current == token, isDismissing else { return false }
        current = nil
        isDismissing = false
        return true
    }
}
