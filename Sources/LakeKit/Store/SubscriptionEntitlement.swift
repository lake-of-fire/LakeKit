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
                                continuation.yield(.init(finish: { await transaction.finish() }))
                            case .unverified(let transaction, _):
                                guard productIDs.contains(transaction.productID) else { continue }
                                // An individual bad transaction must not terminate observation.
                                continuation.yield(.init())
                            }
                        }
                    }
                    let statuses = Task {
                        for await _ in Product.SubscriptionInfo.Status.updates {
                            guard !Task.isCancelled else { break }
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
