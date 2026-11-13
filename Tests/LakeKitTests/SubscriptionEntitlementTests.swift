import Foundation
import XCTest
@testable import LakeKit

final class SubscriptionEntitlementTests: XCTestCase {
    private static let monthly = "premium.monthly"
    private static let annual = "premium.annual"

    @MainActor
    func testConcurrentPurchaseAttemptsAreRejectedUntilFirstOperationCompletes() async {
        await withModel { model in
            let firstStarted = EntitlementTestGate<Void>()
            let releaseFirst = EntitlementTestGate<Void>()
            var operations = 0
            let firstAccepted = model.performPurchase {
                operations += 1
                firstStarted.open(())
                await releaseFirst.wait()
            }
            let firstTask = model.purchaseTask
            await firstStarted.wait()

            let secondAccepted = model.performPurchase { operations += 1 }
            let stateWhileFirstIsPending = model.purchaseState
            releaseFirst.open(())
            await firstTask?.value

            XCTAssertTrue(firstAccepted)
            XCTAssertFalse(secondAccepted)
            XCTAssertEqual(stateWhileFirstIsPending, .inProgress)
            XCTAssertEqual(operations, 1)
            XCTAssertNil(model.purchaseTask)

            let retryStarted = EntitlementTestGate<Void>()
            let retryAccepted = model.performPurchase {
                operations += 1
                model.purchaseState = .notPurchased
                retryStarted.open(())
            }
            let retryTask = model.purchaseTask
            await retryStarted.wait()
            await retryTask?.value

            XCTAssertTrue(retryAccepted)
            XCTAssertEqual(operations, 2)
            XCTAssertEqual(model.purchaseState, .notPurchased)
            XCTAssertNil(model.purchaseTask)
        }
    }

    @MainActor
    func testPendingPurchaseBlocksRetryAfterItsTaskCompletes() async {
        await withModel { model in
            let accepted = model.performPurchase {
                model.purchaseState = .pending
            }
            let task = model.purchaseTask
            await task?.value

            XCTAssertTrue(accepted)
            XCTAssertNil(model.purchaseTask)
            XCTAssertEqual(model.purchaseState, .pending)
            XCTAssertFalse(model.performPurchase {})
            XCTAssertEqual(model.purchaseState, .pending)
        }
    }

    func testSubscriptionPurchasePresentationUsesCanonicalOwnership() {
        XCTAssertEqual(SubscriptionPurchasePolicy.presentationState(entitlementState: .inactive, purchaseState: .purchased), .notPurchased)
        XCTAssertEqual(SubscriptionPurchasePolicy.presentationState(entitlementState: .active, purchaseState: .notPurchased), .purchased)
        XCTAssertEqual(SubscriptionPurchasePolicy.presentationState(entitlementState: .active, purchaseState: .pending), .purchased)
        for state in [SubscriptionEntitlementState.checking, .unavailable] {
            XCTAssertEqual(SubscriptionPurchasePolicy.presentationState(entitlementState: state, purchaseState: .purchased), .unknown)
        }
        for state in [SubscriptionEntitlementState.checking, .inactive, .unavailable] {
            XCTAssertEqual(SubscriptionPurchasePolicy.presentationState(entitlementState: state, purchaseState: .pending), .pending)
        }
        for state in [SubscriptionEntitlementState.checking, .active, .inactive, .unavailable] {
            XCTAssertEqual(SubscriptionPurchasePolicy.presentationState(entitlementState: state, purchaseState: .inProgress), .inProgress)
        }
    }

    @MainActor
    func testApprovedPendingPurchaseDoesNotBlockResubscriptionAfterExpiry() async {
        await withModel { model in
            model.purchaseState = .pending
            model.entitlementClient.current = { [.verified(productID: Self.monthly)] }
            await model.reconcileEntitlements()
            XCTAssertEqual(model.purchaseState, .purchased)

            model.entitlementClient.current = { [] }
            await model.reconcileEntitlements()

            XCTAssertEqual(SubscriptionPurchasePolicy.presentationState(
                entitlementState: model.entitlementState, purchaseState: model.purchaseState
            ), .notPurchased)
        }
    }

    func testVerifiedEntitlementWinsAfterUnverifiedOtherSKU() {
        XCTAssertEqual(SubscriptionEntitlement.state(
            for: [.unverified(productID: Self.monthly), .verified(productID: Self.annual)],
            recognizing: [Self.monthly, Self.annual]
        ), .active)
    }

    func testRevokedAndUpgradedEntitlementsDoNotGrantAccess() {
        XCTAssertEqual(SubscriptionEntitlement.state(
            for: [
                .verified(productID: Self.monthly, revoked: true),
                .verified(productID: Self.annual, upgraded: true),
            ],
            recognizing: [Self.monthly, Self.annual]
        ), .inactive)
    }

    func testUnknownProductIDsDoNotGrantOrInvalidateAccess() {
        XCTAssertEqual(SubscriptionEntitlement.state(
            for: [.verified(productID: "unknown"), .unverified(productID: "another.unknown")],
            recognizing: [Self.monthly]
        ), .inactive)
    }

    func testEmptySnapshotIsInactiveAndRecognizedVerificationFailureIsUnavailable() {
        XCTAssertEqual(SubscriptionEntitlement.state(for: [], recognizing: [Self.monthly]), .inactive)
        XCTAssertEqual(SubscriptionEntitlement.state(
            for: [.unverified(productID: Self.monthly)], recognizing: [Self.monthly]
        ), .unavailable)
    }

    @MainActor
    func testRecognizedEntitlementGrantsPremiumWithoutLoadedProductMetadata() async {
        await withModel { model in
            XCTAssertTrue(model.products.isEmpty)
            XCTAssertTrue(model.studentProducts.isEmpty)
            XCTAssertEqual(model.entitlementState, .checking)
            XCTAssertFalse(model.isInitialized)
            XCTAssertTrue(model.showAds)
            model.entitlementClient.current = { [.verified(productID: Self.monthly)] }

            await model.reconcileEntitlements()

            XCTAssertEqual(model.entitlementState, .active)
            XCTAssertTrue(model.isSubscribed)
            XCTAssertTrue(model.isInitialized)
            XCTAssertFalse(AdsViewModel.shared.showAds)
            XCTAssertTrue(AdsViewModel.shared.isInitialized)
        }
    }

    @MainActor
    func testCurrentEntitlementErrorPublishesUnavailableWithoutPremium() async {
        await withModel { model in
            model.entitlementClient.current = { throw FixtureError.offline }

            await model.reconcileEntitlements()

            XCTAssertEqual(model.entitlementState, .unavailable)
            XCTAssertFalse(model.isSubscribed)
            XCTAssertTrue(model.isInitialized)
            XCTAssertTrue(AdsViewModel.shared.showAds)
        }
    }

    @MainActor
    func testExternalAccountErrorPublishesUnavailableWithoutPremium() async {
        await withModel { model in
            model.isSubscribedFromElsewhereCallback = { _ in throw FixtureError.offline }

            await model.reconcileEntitlements()

            XCTAssertEqual(model.entitlementState, .unavailable)
            XCTAssertFalse(model.isSubscribed)
            XCTAssertFalse(model.isSubscribedFromElsewhere)
            XCTAssertTrue(model.showAds)
        }
    }

    @MainActor
    func testNegativeAndUnavailableResultsBecomeCheckingWhileAppleReadIsPending() async {
        let cases: [([SubscriptionEntitlement], SubscriptionEntitlementState)] = [
            ([], .inactive),
            ([.unverified(productID: Self.monthly)], .unavailable),
        ]
        for (initialSnapshot, initialState) in cases {
            await withModel { model in
                model.entitlementClient.current = { initialSnapshot }
                model.isSubscribedFromElsewhereCallback = { _ in false }
                await model.reconcileEntitlements()
                XCTAssertEqual(model.entitlementState, initialState)

                let readStarted = EntitlementTestGate<Void>()
                let releaseRead = EntitlementTestGate<[SubscriptionEntitlement]>()
                model.entitlementClient.current = {
                    readStarted.open(())
                    return await releaseRead.wait()
                }
                let refresh = Task { @MainActor in await model.reconcileEntitlements() }
                await readStarted.wait()
                XCTAssertEqual(model.entitlementState, .checking)
                await model.externalSubscriptionTask?.value
                XCTAssertEqual(model.entitlementState, .checking, "A completed negative backend check cannot decide Apple ownership")
                XCTAssertFalse(model.isInitialized)
                XCTAssertTrue(AdsViewModel.shared.showAds)

                releaseRead.open([.verified(productID: Self.monthly)])
                await refresh.value
                XCTAssertTrue(model.isSubscribed)
            }
        }
    }

    @MainActor
    func testRestoreExplicitlyRescansWhenPurchasedSKUHasNotChanged() async {
        await withModel { model in
            var snapshot: [SubscriptionEntitlement] = [.verified(productID: Self.monthly, revoked: true)]
            var reads = 0
            var syncs = 0
            model.entitlementClient.current = {
                reads += 1
                return snapshot
            }
            model.entitlementClient.sync = {
                syncs += 1
                snapshot = [.verified(productID: Self.monthly)]
            }
            await model.reconcileEntitlements()
            XCTAssertEqual(model.entitlementState, .inactive)

            await model.restorePurchases()

            XCTAssertEqual(syncs, 1)
            XCTAssertEqual(reads, 2)
            XCTAssertTrue(model.isSubscribed)
            XCTAssertNil(model.restorePurchasesError)
            XCTAssertFalse(model.isRestoringPurchases)
        }
    }

    @MainActor
    func testRestoreSyncFailureIsSurfacedAndDoesNotDiscardVerifiedAccess() async {
        await withModel { model in
            var reads = 0
            model.entitlementClient.current = {
                reads += 1
                return [.verified(productID: Self.monthly)]
            }
            model.entitlementClient.sync = { throw FixtureError.offline }
            await model.reconcileEntitlements()

            await model.restorePurchases()

            XCTAssertEqual(model.restorePurchasesError, FixtureError.offline.localizedDescription)
            XCTAssertEqual(reads, 1)
            XCTAssertTrue(model.isSubscribed)
            XCTAssertFalse(model.isRestoringPurchases)
        }
    }

    @MainActor
    func testRestoreReportsVerificationFailureAfterSuccessfulSync() async {
        await withModel { model in
            model.entitlementClient.current = { [.unverified(productID: Self.monthly)] }

            await model.restorePurchases()

            XCTAssertEqual(model.entitlementState, .unavailable)
            XCTAssertNotNil(model.restorePurchasesError)
            XCTAssertFalse(model.isRestoringPurchases)
        }
    }

    @MainActor
    func testRestoreReportsNoActiveSubscriptionAfterSuccessfulSync() async {
        await withModel { model in
            await model.restorePurchases()

            XCTAssertEqual(model.entitlementState, .inactive)
            XCTAssertFalse(model.isSubscribed)
            XCTAssertNotNil(model.restorePurchasesError)
            XCTAssertFalse(model.isRestoringPurchases)
        }
    }

    @MainActor
    func testConcurrentRestoresShareSynchronizationAndCompletedError() async {
        await withModel { model in
            let syncStarted = EntitlementTestGate<Void>()
            let releaseSync = EntitlementTestGate<Void>()
            let secondStarted = EntitlementTestGate<Void>()
            var syncs = 0
            var secondReturned = false
            model.entitlementClient.sync = {
                syncs += 1
                syncStarted.open(())
                await releaseSync.wait()
                throw FixtureError.offline
            }
            let first = Task { @MainActor in await model.restorePurchases() }
            await syncStarted.wait()
            let second = Task { @MainActor in
                secondStarted.open(())
                let error = await model.restorePurchases()
                secondReturned = true
                return error
            }
            await secondStarted.wait()
            XCTAssertFalse(secondReturned)
            XCTAssertTrue(model.isRestoringPurchases)
            XCTAssertEqual(syncs, 1)

            releaseSync.open(())
            let firstError = await first.value
            let secondError = await second.value
            XCTAssertEqual(firstError, FixtureError.offline.localizedDescription)
            XCTAssertEqual(secondError, firstError)
            XCTAssertEqual(model.restorePurchasesError, firstError)
            XCTAssertFalse(model.isRestoringPurchases)
            XCTAssertEqual(syncs, 1)
        }
    }

    @MainActor
    func testRestoreReportsInterruptedVerificationDuringAccountTransition() async {
        await withModel { model in
            let backendStarted = EntitlementTestGate<Void>()
            let releaseBackend = EntitlementTestGate<Bool>()
            model.isSubscribedFromElsewhereCallback = { _ in
                backendStarted.open(())
                return await releaseBackend.wait()
            }
            let restore = Task { @MainActor in await model.restorePurchases() }
            await backendStarted.wait()
            let obsoleteWorker = model.externalSubscriptionTask
            // Apple has completed without a grant, but the departing account's
            // backend check has not returned. Retiring it must not imply success.
            await model.subscriptionRefreshTask?.value
            XCTAssertTrue(model.isRestoringPurchases)
            model.invalidateExternalSubscription()

            let error = await restore.value

            XCTAssertEqual(model.entitlementState, .checking)
            XCTAssertFalse(model.isSubscribed)
            XCTAssertNotNil(error)
            XCTAssertEqual(model.restorePurchasesError, error)
            XCTAssertFalse(model.isRestoringPurchases)
            releaseBackend.open(true)
            await obsoleteWorker?.value
            XCTAssertFalse(model.isSubscribed, "A retired account cannot complete Restore later")

            model.isSubscribedFromElsewhereCallback = { _ in false }
            model.resumeExternalSubscription()
            await model.reconcileEntitlements()
            XCTAssertEqual(model.entitlementState, .inactive)
        }
    }

    @MainActor
    func testAccountInvalidationDoesNotCancelPendingAppleEntitlementRead() async {
        await withModel { model in
            let readStarted = EntitlementTestGate<Void>()
            let releaseRead = EntitlementTestGate<[SubscriptionEntitlement]>()
            let readReturned = EntitlementTestGate<Bool>()
            model.isSubscribedFromElsewhereCallback = { _ in false }
            model.entitlementClient.current = {
                readStarted.open(())
                let snapshot = await releaseRead.wait()
                readReturned.open(Task.isCancelled)
                return snapshot
            }
            let refresh = Task { @MainActor in await model.reconcileEntitlements() }
            await readStarted.wait()

            model.invalidateExternalSubscription()
            releaseRead.open([.verified(productID: Self.monthly)])
            let wasCancelled = await readReturned.wait()
            await refresh.value

            XCTAssertFalse(wasCancelled)
            XCTAssertTrue(model.isSubscribed)
            XCTAssertFalse(model.isSubscribedFromElsewhere)
            XCTAssertFalse(AdsViewModel.shared.showAds)
        }
    }

    @MainActor
    func testAccountObservationRetiresExternalGrantWithoutAnyMountedView() async {
        await withModel { model in
            let session = Session.ephemeralForTesting()
            session.authenticated(authToken: "premium-fixture", userID: 42)
            let granted = EntitlementTestGate<Void>()
            let signedOutChecked = EntitlementTestGate<Void>()
            var externalReads = 0
            model.isSubscribedFromElsewhereCallback = { _ in
                externalReads += 1
                if session.accountSessionSnapshot.identity == .authenticated(userID: 42) {
                    granted.open(())
                    return true
                }
                signedOutChecked.open(())
                return false
            }
            model.observeExternalSubscriptionAccount(session)
            model.observeExternalSubscriptionAccount(session)
            await granted.wait()
            await model.externalSubscriptionTask?.value
            XCTAssertTrue(model.isSubscribedFromElsewhere)
            XCTAssertTrue(model.isSubscribed)

            XCTAssertTrue(session.logout())
            // Invalidation is synchronous with the account boundary, independent
            // of reader/Settings appearance and before the replacement query.
            XCTAssertFalse(model.isSubscribedFromElsewhere)
            XCTAssertFalse(model.isSubscribed)
            await signedOutChecked.wait()
            await model.externalSubscriptionTask?.value
            await model.subscriptionRefreshTask?.value
            XCTAssertEqual(model.entitlementState, .inactive)
            XCTAssertEqual(externalReads, 2, "Repeated setup must not add account observers")
        }
    }

    @MainActor
    func testAccountInvalidationPreservesAppleGrantUntilFreshSnapshotReplacesIt() async {
        await withModel { model in
            model.isSubscribedFromElsewhereCallback = { _ in false }
            model.entitlementClient.current = { [.verified(productID: Self.monthly)] }
            await model.reconcileEntitlements()

            let readStarted = EntitlementTestGate<Void>()
            let releaseRead = EntitlementTestGate<[SubscriptionEntitlement]>()
            model.entitlementClient.current = {
                readStarted.open(())
                return await releaseRead.wait()
            }
            let refresh = Task { @MainActor in await model.reconcileEntitlements() }
            await readStarted.wait()

            model.invalidateExternalSubscription()
            XCTAssertTrue(model.isSubscribed)
            XCTAssertFalse(AdsViewModel.shared.showAds)

            // A completed negative StoreKit snapshot still withdraws Apple access.
            releaseRead.open([])
            await refresh.value
            XCTAssertFalse(model.isSubscribed)
            XCTAssertEqual(model.entitlementState, .checking, "The Manabi account is still transitioning")
            XCTAssertTrue(AdsViewModel.shared.showAds)

            model.entitlementClient.current = { [] }
            model.resumeExternalSubscription()
            await model.reconcileEntitlements()
            XCTAssertEqual(model.entitlementState, .inactive)
        }
    }

    @MainActor
    func testUpdatesContinueAfterUnverifiedRevokedAndUpgradedEventsAndFinishAfterReconciliation() async {
        await withModel { model in
            var continuation: AsyncStream<SubscriptionEntitlementUpdate>.Continuation!
            let stream = AsyncStream<SubscriptionEntitlementUpdate> { continuation = $0 }
            defer { continuation.finish() }
            var snapshot: [SubscriptionEntitlement] = []
            var observedProductIDs: Set<String> = []
            var observers = 0
            model.entitlementClient.current = { snapshot }
            model.invalidateExternalSubscription()
            model.entitlementClient.updates = { productIDs in
                observedProductIDs = productIDs
                observers += 1
                return stream
            }
            model.startMonitoringEntitlements()
            model.startMonitoringEntitlements()
            XCTAssertEqual(observers, 1)
            XCTAssertEqual(observedProductIDs, [Self.monthly, Self.annual])

            let events: [([SubscriptionEntitlement], SubscriptionEntitlementState)] = [
                ([.unverified(productID: Self.monthly)], .unavailable),
                ([.verified(productID: Self.monthly, revoked: true)], .inactive),
                ([.verified(productID: Self.monthly, upgraded: true)], .inactive),
                ([.verified(productID: Self.annual)], .active),
            ]
            for (entitlements, expectedState) in events {
                snapshot = entitlements
                let finished = EntitlementTestGate<SubscriptionEntitlementState>()
                continuation.yield(.init(finish: {
                    await finished.open(model.entitlementState)
                }))
                let stateWhenFinished = await finished.wait()
                XCTAssertEqual(stateWhenFinished, expectedState)
                XCTAssertEqual(model.entitlementState, expectedState)
            }
            XCTAssertTrue(model.isSubscribed)
        }
    }

    @MainActor
    func testLateCanceledAppleSnapshotCannotOverwriteNewerResult() async {
        await withModel { model in
            let firstReadStarted = EntitlementTestGate<Void>()
            let releaseFirstRead = EntitlementTestGate<[SubscriptionEntitlement]>()
            let firstReadReturned = EntitlementTestGate<Void>()
            var reads = 0
            model.entitlementClient.current = {
                reads += 1
                if reads == 1 {
                    firstReadStarted.open(())
                    // Deliberately ignores cancellation, like a late external completion.
                    let result = await releaseFirstRead.wait()
                    firstReadReturned.open(())
                    return result
                }
                return []
            }
            let firstRefresh = Task { @MainActor in await model.reconcileEntitlements() }
            await firstReadStarted.wait()
            let obsoleteWorker = model.subscriptionRefreshTask

            await model.reconcileEntitlements()
            XCTAssertEqual(model.entitlementState, .inactive)
            releaseFirstRead.open([.verified(productID: Self.monthly)])
            await firstReadReturned.wait()
            await obsoleteWorker?.value
            await firstRefresh.value

            XCTAssertEqual(model.entitlementState, .inactive)
            XCTAssertFalse(model.isSubscribed)
        }
    }

    @MainActor
    func testVerifiedAppleGrantDoesNotWaitForExternalAccount() async {
        await withModel { model in
            let externalStarted = EntitlementTestGate<Void>()
            let releaseExternal = EntitlementTestGate<Bool>()
            let externalReturned = EntitlementTestGate<Void>()
            model.entitlementClient.current = { [.verified(productID: Self.monthly)] }
            model.isSubscribedFromElsewhereCallback = { _ in
                externalStarted.open(())
                let result = await releaseExternal.wait()
                externalReturned.open(())
                return result
            }
            let refresh = Task { @MainActor in await model.reconcileEntitlements() }
            await externalStarted.wait()
            let externalWorker = model.externalSubscriptionTask
            await refresh.value

            XCTAssertTrue(model.isSubscribed)
            XCTAssertEqual(model.entitlementState, .active)
            releaseExternal.open(false)
            await externalReturned.wait()
            await externalWorker?.value
            XCTAssertTrue(model.isSubscribed)
        }
    }

    @MainActor
    func testExternalGrantDoesNotWaitForStalledAppleRead() async {
        await withModel { model in
            let readStarted = EntitlementTestGate<Void>()
            let releaseRead = EntitlementTestGate<[SubscriptionEntitlement]>()
            let readReturned = EntitlementTestGate<Void>()
            model.entitlementClient.current = {
                readStarted.open(())
                let snapshot = await releaseRead.wait()
                readReturned.open(())
                return snapshot
            }
            model.isSubscribedFromElsewhereCallback = { _ in true }
            let refresh = Task { @MainActor in await model.reconcileEntitlements() }
            await readStarted.wait()
            let appleWorker = model.subscriptionRefreshTask
            await refresh.value

            XCTAssertTrue(model.isSubscribed)
            XCTAssertTrue(model.isSubscribedFromElsewhere)
            releaseRead.open([])
            await readReturned.wait()
            await appleWorker?.value
            XCTAssertTrue(model.isSubscribed)
        }
    }

    @MainActor
    func testConfirmedExternalGrantSurvivesRefreshUntilFreshNegativeOrError() async {
        for fails in [false, true] {
            await withModel { model in
                model.isSubscribedFromElsewhereCallback = { _ in true }
                await model.reconcileEntitlements()
                XCTAssertTrue(model.isSubscribedFromElsewhere)

                let started = EntitlementTestGate<Void>()
                let release = EntitlementTestGate<Void>()
                model.isSubscribedFromElsewhereCallback = { _ in
                    started.open(())
                    await release.wait()
                    if fails { throw FixtureError.offline }
                    return false
                }
                let refresh = Task { @MainActor in await model.reconcileEntitlements() }
                await started.wait()
                await model.subscriptionRefreshTask?.value

                XCTAssertTrue(model.isSubscribed)
                XCTAssertTrue(model.isSubscribedFromElsewhere)
                XCTAssertFalse(AdsViewModel.shared.showAds)

                release.open(())
                await refresh.value
                XCTAssertEqual(model.entitlementState, fails ? .unavailable : .inactive)
                XCTAssertFalse(model.isSubscribed)
                XCTAssertFalse(model.isSubscribedFromElsewhere)
                XCTAssertTrue(AdsViewModel.shared.showAds)
            }
        }
    }

    @MainActor
    func testRestoreWaitsForFreshExternalResultDespiteRetainedGrant() async {
        await withModel { model in
            model.isSubscribedFromElsewhereCallback = { _ in true }
            await model.reconcileEntitlements()
            let started = EntitlementTestGate<Void>()
            let release = EntitlementTestGate<Void>()
            model.isSubscribedFromElsewhereCallback = { _ in
                started.open(())
                await release.wait()
                return false
            }
            let restore = Task { @MainActor in await model.restorePurchases() }
            await started.wait()
            await model.subscriptionRefreshTask?.value
            XCTAssertTrue(model.isSubscribed)
            XCTAssertTrue(model.isRestoringPurchases, "A cached grant must not complete Restore")

            release.open(())
            let error = await restore.value
            XCTAssertNotNil(error)
            XCTAssertEqual(model.entitlementState, .inactive)
            XCTAssertFalse(model.isRestoringPurchases)
        }
    }

    @MainActor
    func testRestoreCompletesAfterNewAppleGrantBeforeCanceledBackendReturns() async {
        await withModel { model in
            var snapshot: [SubscriptionEntitlement] = []
            let backendStarted = EntitlementTestGate<Void>()
            let releaseBackend = EntitlementTestGate<Bool>()
            let backendReturned = EntitlementTestGate<Void>()
            model.entitlementClient.current = { snapshot }
            model.isSubscribedFromElsewhereCallback = { _ in
                backendStarted.open(())
                let result = await releaseBackend.wait()
                backendReturned.open(())
                return result
            }
            let restore = Task { @MainActor in await model.restorePurchases() }
            await backendStarted.wait()
            let obsoleteWorker = model.externalSubscriptionTask
            XCTAssertTrue(model.isRestoringPurchases)

            snapshot = [.verified(productID: Self.monthly)]
            // The new account result is immediate; the canceled provider remains suspended.
            model.isSubscribedFromElsewhereCallback = { _ in false }
            await model.reconcileEntitlements()
            await restore.value

            XCTAssertTrue(model.isSubscribed)
            XCTAssertFalse(model.isRestoringPurchases)
            XCTAssertNil(model.restorePurchasesError)
            releaseBackend.open(false)
            await backendReturned.wait()
            await obsoleteWorker?.value
            XCTAssertTrue(model.isSubscribed)
        }
    }

    @MainActor
    func testMonitorProcessesRevocationAndRenewalWhileExternalAccountIsStalled() async {
        await withModel { model in
            var continuation: AsyncStream<SubscriptionEntitlementUpdate>.Continuation!
            let stream = AsyncStream<SubscriptionEntitlementUpdate> { continuation = $0 }
            defer { continuation.finish() }
            var snapshot: [SubscriptionEntitlement] = []
            let releaseExternal = EntitlementTestGate<Bool>()
            let externalStarted = (0..<3).map { _ in EntitlementTestGate<Void>() }
            let externalReturned = (0..<3).map { _ in EntitlementTestGate<Void>() }
            var externalReads = 0
            var externalWorkers: [Task<Void, Never>] = []
            model.entitlementClient.current = { snapshot }
            model.entitlementClient.updates = { _ in stream }
            model.isSubscribedFromElsewhereCallback = { _ in
                let index = externalReads
                externalReads += 1
                externalStarted[index].open(())
                let result = await releaseExternal.wait()
                externalReturned[index].open(())
                return result
            }
            model.startMonitoringEntitlements()

            let events: [([SubscriptionEntitlement], SubscriptionEntitlementState)] = [
                ([.verified(productID: Self.monthly)], .active),
                ([.verified(productID: Self.monthly, revoked: true)], .checking),
                ([.verified(productID: Self.annual)], .active),
            ]
            for (index, event) in events.enumerated() {
                snapshot = event.0
                let finished = EntitlementTestGate<SubscriptionEntitlementState>()
                continuation.yield(.init(finish: {
                    await finished.open(model.entitlementState)
                }))
                let stateWhenFinished = await finished.wait()
                await externalStarted[index].wait()
                if let worker = model.externalSubscriptionTask { externalWorkers.append(worker) }
                XCTAssertEqual(stateWhenFinished, event.1)
                XCTAssertEqual(model.isSubscribed, event.1 == .active)
                XCTAssertEqual(AdsViewModel.shared.showAds, event.1 != .active)
            }

            // Late canceled callbacks must be harmless, including after the final renewal.
            model.invalidateExternalSubscription()
            releaseExternal.open(true)
            for returned in externalReturned { await returned.wait() }
            for worker in externalWorkers { await worker.value }
            XCTAssertTrue(model.isSubscribed)
            XCTAssertFalse(model.isSubscribedFromElsewhere)
        }
    }

    @MainActor
    func testLateDepartingAccountGrantCannotOverwriteNewAccountResult() async {
        await withModel { model in
            let departingAccountStarted = EntitlementTestGate<Void>()
            let releaseDepartingAccount = EntitlementTestGate<Bool>()
            let departingAccountReturned = EntitlementTestGate<Void>()
            var externalReads = 0
            model.isSubscribedFromElsewhereCallback = { _ in
                externalReads += 1
                if externalReads == 1 {
                    departingAccountStarted.open(())
                    let result = await releaseDepartingAccount.wait()
                    departingAccountReturned.open(())
                    return result
                }
                return false
            }
            let oldRefresh = Task { @MainActor in await model.reconcileEntitlements() }
            await departingAccountStarted.wait()
            let obsoleteWorker = model.externalSubscriptionTask

            model.invalidateExternalSubscription()
            model.resumeExternalSubscription()
            await model.reconcileEntitlements()
            releaseDepartingAccount.open(true)
            await departingAccountReturned.wait()
            await obsoleteWorker?.value
            await oldRefresh.value

            XCTAssertEqual(externalReads, 2)
            XCTAssertEqual(model.entitlementState, .inactive)
            XCTAssertFalse(model.isSubscribedFromElsewhere)
        }
    }

    @MainActor
    func testInvalidationSuppressesExternalAccountReadsUntilResume() async {
        await withModel { model in
            var externalReads = 0
            model.isSubscribedFromElsewhereCallback = { _ in
                externalReads += 1
                return true
            }
            await model.reconcileEntitlements()
            XCTAssertTrue(model.isSubscribedFromElsewhere)

            model.invalidateExternalSubscription()
            XCTAssertFalse(model.isSubscribedFromElsewhere)
            XCTAssertEqual(model.entitlementState, .checking)
            await model.reconcileEntitlements()
            XCTAssertEqual(externalReads, 1)
            XCTAssertFalse(model.isSubscribed)
            XCTAssertEqual(model.entitlementState, .checking)

            model.resumeExternalSubscription()
            await model.reconcileEntitlements()
            XCTAssertEqual(externalReads, 2)
            XCTAssertTrue(model.isSubscribedFromElsewhere)
            XCTAssertTrue(model.isSubscribed)
        }
    }

    @MainActor
    private func withModel(_ body: @MainActor (StoreViewModel) async -> Void) async {
        let ads = AdsViewModel.shared
        let savedShowAds = ads.showAds
        let savedInitialized = ads.isInitialized
        defer {
            ads.showAds = savedShowAds
            ads.isInitialized = savedInitialized
        }
        let model = StoreViewModel(
            products: [], studentProducts: [], highlightedProductID: Self.monthly,
            headline: "Premium", subheadline: "", productGroupHeading: "", productGroupSubtitle: nil,
            awardTitle: nil, awardImage: nil, awardTestimonial: "", awardLink: nil, benefits: [],
            termsOfService: URL(string: "https://example.com/terms")!,
            privacyPolicy: URL(string: "https://example.com/privacy")!, faq: [:],
            additionalSubscriptionProductIDs: [Self.monthly, Self.annual]
        )
        model.entitlementClient = .init(current: { [] }, sync: {}, updates: { _ in
            AsyncStream { $0.finish() }
        })
        await body(model)
        // Fence any independent callback before restoring the process-wide ad fixture.
        model.invalidateExternalSubscription()
        model.entitlementClient.current = { [] }
        await model.reconcileEntitlements()
    }
}

private enum FixtureError: LocalizedError {
    case offline
    var errorDescription: String? { "Fixture StoreKit connection failed." }
}

/// One-shot rendezvous: event order is controlled by continuations, never scheduler delays.
@MainActor
private final class EntitlementTestGate<Value: Sendable> {
    private var value: Value?
    private var continuations: [CheckedContinuation<Value, Never>] = []

    func wait() async -> Value {
        if let value { return value }
        return await withCheckedContinuation { continuations.append($0) }
    }

    func open(_ value: Value) {
        precondition(self.value == nil, "A test gate can only be opened once")
        self.value = value
        for continuation in continuations { continuation.resume(returning: value) }
        continuations = []
    }
}
