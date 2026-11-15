import Foundation
import StoreKit

public enum SubscriptionEntitlementState: Equatable, Sendable {
    case checking
    case active
    case inactive
    case unavailable
}

/// Evidence from StoreKit's current-entitlements sequence, not its product catalog.
/// Membership includes billing grace periods; expirationDate alone cannot decide access.
enum SubscriptionEntitlement: Sendable {
    case verified(productID: String, revoked: Bool = false, upgraded: Bool = false)
    case unverified(productID: String)

    var productID: String {
        switch self {
        case .verified(let id, _, _), .unverified(let id): return id
        }
    }

    static func state(for entitlements: [Self], recognizing productIDs: Set<String>) -> SubscriptionEntitlementState {
        var hasVerificationFailure = false
        for entitlement in entitlements where productIDs.contains(entitlement.productID) {
            switch entitlement {
            case .verified(_, revoked: false, upgraded: false): return .active
            case .verified: continue
            case .unverified: hasVerificationFailure = true
            }
        }
        // An empty sequence has no error channel. Do not silently turn an old Boolean
        // into an indefinite grant, or claim that we can detect every StoreKit outage.
        return hasVerificationFailure ? .unavailable : .inactive
    }
}

struct SubscriptionEntitlementUpdate: Sendable {
    var finish: (@Sendable () async -> Void)?
}

/// Injectable StoreKit boundary used by the same reconciliation code in tests and the app.
@MainActor
struct SubscriptionEntitlementClient {
    var current: () async throws -> [SubscriptionEntitlement]
    var sync: () async throws -> Void
    var updates: (Set<String>) -> AsyncStream<SubscriptionEntitlementUpdate>

    static var live: Self {
        Self(
            current: {
                var entitlements: [SubscriptionEntitlement] = []
                for await result in StoreKit.Transaction.currentEntitlements {
                    try Task.checkCancellation()
                    switch result {
                    case .verified(let transaction):
#if DEBUG
                        SubscriptionEntitlementDiagnostics.transaction("current", transaction)
#endif
                        entitlements.append(.verified(
                            productID: transaction.productID,
                            revoked: transaction.revocationDate != nil,
                            upgraded: transaction.isUpgraded
                        ))
                    case .unverified(let transaction, _):
                        entitlements.append(.unverified(productID: transaction.productID))
                    }
                }
                return entitlements
            },
            sync: { try await AppStore.sync() },
            updates: { productIDs in
                AsyncStream { continuation in
                    let transactions = Task {
                        for await result in StoreKit.Transaction.updates {
                            guard !Task.isCancelled else { break }
                            switch result {
                            case .verified(let transaction):
                                guard productIDs.contains(transaction.productID) else { continue }
#if DEBUG
                                SubscriptionEntitlementDiagnostics.transaction("transaction-event", transaction)
#endif
                                continuation.yield(.init(finish: { await transaction.finish() }))
                            case .unverified(let transaction, _):
                                guard productIDs.contains(transaction.productID) else { continue }
                                // An individual bad transaction must not terminate observation.
                                continuation.yield(.init())
                            }
                        }
                    }
                    let statuses = Task {
                        for await status in Product.SubscriptionInfo.Status.updates {
                            guard !Task.isCancelled else { break }
#if DEBUG
                            if case .verified(let transaction) = status.transaction,
                               productIDs.contains(transaction.productID) {
                                SubscriptionEntitlementDiagnostics.transaction("status-event state=\(status.state)", transaction)
                            }
#endif
                            // Grace/retry/expiration can change without adding a purchased SKU.
                            continuation.yield(.init())
                        }
                    }
                    continuation.onTermination = { _ in
                        transactions.cancel()
                        statuses.cancel()
                    }
                }
            }
        )
    }
}

#if DEBUG
/// Opt-in diagnostics for authentic local StoreKit integration runs only.
@MainActor
enum SubscriptionEntitlementDiagnostics {
    private(set) static var lines: [String] = []

    static func beginScenario(_ label: String) {
        lines.removeAll(keepingCapacity: true)
        record("scenario=\(label)")
    }

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["MANABI_STOREKIT_DIAGNOSTICS"] == "1"
    }

    static func record(_ message: String) {
        guard isEnabled else { return }
        guard lines.count < 256 else { return }
        let line = "[PremiumStoreKit] time=\(Date().timeIntervalSince1970) \(message.prefix(512))"
        lines.append(line)
        print(line)
    }

    static func transaction(_ source: String, _ transaction: StoreKit.Transaction) {
        guard isEnabled else { return }
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            guard transaction.environment == .xcode else { return }
            record("source=\(source) localID=\(transaction.id) product=\(transaction.productID) "
                + "purchase=\(transaction.purchaseDate.timeIntervalSince1970) "
                + "expiration=\(transaction.expirationDate?.timeIntervalSince1970.description ?? "nil") "
                + "revoked=\(transaction.revocationDate != nil) upgraded=\(transaction.isUpgraded)")
        }
    }
}
#endif
