import SwiftUI
import OrderedCollections
import StoreKit
import StoreHelper
import Combine

#if DEBUG
private let lakeKitPretendSubscriptionEnabled = ProcessInfo.processInfo.arguments.contains("pretend-subscribed")
#endif

@MainActor
public class AdsViewModel: NSObject, ObservableObject {
    public static var shared = AdsViewModel()
    
    @Published public var isInitialized = false
    @Published public var showAds = true
}

@MainActor
public class StoreViewModel: NSObject, ObservableObject {
    /// Validates and reserves  a referral code asynchronously.
    let reserveReferralCodeForPurchase: (String, UUID) async throws -> Void
    /// For server overrides, other apps, etc.
    public var isInitialized: Bool { entitlementState != .checking }
    @Published public private(set) var entitlementState: SubscriptionEntitlementState = .checking
    @Published public var restorePurchasesError: String?
    
    @Published public private(set) var isRestoringPurchases = false
    
    let satisfyingPrerequisite: () async -> Bool
    
    let highlightedProductID: String
    @Published public var products: [StoreProductVersions]
    @Published public var studentProducts: [StoreProductVersions]
    
    @Published public var headline: String
    @Published public var subheadline: String
    public let purchaseEnvironmentNotice: String?
    @Published public var productGroupHeading: String
    @Published public var productGroupSubtitle: String?
    @Published public var freeTierExplanation: String?
    @Published public var awardTitle: String?
    @Published public var awardImage: Image?
    @Published public var awardTestimonial: String?
    @Published public var awardLink: URL?
    @Published public var benefits: [String]
    @Published public var termsOfService: URL
    @Published public var privacyPolicy: URL
    @Published public var chatURL: URL? = nil
    @Published public var faq = OrderedDictionary<String, String>()
    
    @Published public var purchaseState: PurchaseState = .unknown
    
    @AppStorage("pendingReferralCode") private var pendingReferralCode: String?
    public var isSubscribed: Bool { entitlementState == .active }
    @Published public private(set) var isSubscribedFromElsewhere = false
    @MainActor var isSubscribedFromElsewhereCallback: ((StoreViewModel) async throws -> Bool)? = nil
    // Internal read access lets regression tests join obsolete workers after
    // releasing their providers. UI callers use reconcileEntitlements().
    private(set) var subscriptionRefreshTask: Task<Void, Never>?
    private var subscriptionMonitorTask: Task<Void, Never>?
    private(set) var externalSubscriptionTask: Task<Void, Never>?
    private var restorePurchasesTask: Task<String?, Never>?
    private var externalAccountObservation: AnyCancellable?
    private var externalEntitlementState: SubscriptionEntitlementState = .inactive
    private var subscriptionRefreshGeneration: UInt64 = 0
    private var externalSubscriptionGeneration: UInt64 = 0
    private var appleRefreshPending = false
    private var externalRefreshPending = false
    private var reconciliationWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var appleEntitlementState: SubscriptionEntitlementState = .checking
    private var externalSubscriptionEnabled = true
    private let additionalSubscriptionProductIDs: Set<String>
    var entitlementClient = SubscriptionEntitlementClient.live

    var subscriptionProductIDs: Set<String> {
        Set((products + studentProducts).flatMap { [$0.product, $0.referralProduct] }
            .filter(\.isSubscription).map(\.id)).union(additionalSubscriptionProductIDs)
    }

    private var hasExternalSubscriptionProvider: Bool {
        #if DEBUG
        return isSubscribedFromElsewhereCallback != nil || lakeKitPretendSubscriptionEnabled
        #else
        return isSubscribedFromElsewhereCallback != nil
        #endif
    }
    
    public init(
        satisfyingPrerequisite: @escaping () async -> Bool = { true },
        products: [StoreProductVersions],
        studentProducts: [StoreProductVersions],
        highlightedProductID: String,
        headline: String,
        subheadline: String,
        purchaseEnvironmentNotice: String? = nil,
        productGroupHeading: String,
        productGroupSubtitle: String?,
        freeTierExplanation: String? = nil,
        awardTitle: String?,
        awardImage: Image?,
        awardTestimonial: String,
        awardLink: URL?,
        benefits: [String],
        termsOfService: URL,
        privacyPolicy: URL,
        chatURL: URL? = nil,
        faq: OrderedDictionary<String, String>,
        isSubscribedFromElsewhereCallback: ((StoreViewModel) async throws -> Bool)? = nil,
        reserveReferralCodeForPurchase: @escaping (String, UUID) async throws -> Void = { _, _ in },
        additionalSubscriptionProductIDs: Set<String> = []
    ) {
        self.satisfyingPrerequisite = satisfyingPrerequisite
        self.products = products
        self.studentProducts = studentProducts
        self.highlightedProductID = highlightedProductID
        self.headline = headline
        self.subheadline = subheadline
        self.purchaseEnvironmentNotice = purchaseEnvironmentNotice
        self.productGroupHeading = productGroupHeading
        self.productGroupSubtitle = productGroupSubtitle
        self.freeTierExplanation = freeTierExplanation
        self.awardTitle = awardTitle
        self.awardImage = awardImage
        self.awardTestimonial = awardTestimonial
        self.awardLink = awardLink
        self.benefits = benefits
        self.termsOfService = termsOfService
        self.privacyPolicy = privacyPolicy
        self.chatURL = chatURL
        self.faq = faq
        self.isSubscribedFromElsewhereCallback = isSubscribedFromElsewhereCallback
        self.reserveReferralCodeForPurchase = reserveReferralCodeForPurchase
        self.additionalSubscriptionProductIDs = additionalSubscriptionProductIDs
    }
    
    /// Returns the app account token UUID, reading from UserDefaults or generating and storing a new one if not present.
    @MainActor
    static func getOrCreateAppAccountToken() -> UUID {
        let key = "appAccountToken"
        if let existing = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: existing) {
            return uuid
        } else {
            let newUUID = UUID()
            UserDefaults.standard.set(newUUID.uuidString, forKey: key)
            return newUUID
        }
    }
    
    public var productGridColumns: [GridItem] {
        return [GridItem(.adaptive(minimum: 200), spacing: 20)]
    }
    
    public var showAds: Bool {
        return !isSubscribed
    }
    
    @MainActor
    public func productSubscriptionInfo(productID: String, storeHelper: StoreHelper) async -> PrePurchaseSubscriptionInfo? {
        let productIDs = (products + studentProducts).map { $0.id }
        let priceViewModel = PriceViewModel(storeHelper: storeHelper, purchaseState: .constant(.notStarted))
        let prePurchaseSubInfo = await priceViewModel.getPrePurchaseSubscriptionInfo(productId: highlightedProductID)
        return prePurchaseSubInfo
    }
    
    @MainActor
    public func purchase(storeProduct: StoreProduct, storeKitProduct: Product, priceViewModel: PriceViewModel) {
        guard storeProduct.filterPurchase(storeProduct) else { return }
        purchaseState = .inProgress
        Task { @MainActor in
            let appAccountToken = Self.getOrCreateAppAccountToken()
            await priceViewModel.purchase(product: storeKitProduct, options: [
                .appAccountToken(appAccountToken),
            ])
            await reconcileEntitlements()
        }
    }
    
    deinit {
        subscriptionRefreshTask?.cancel()
        externalSubscriptionTask?.cancel()
        subscriptionMonitorTask?.cancel()
        restorePurchasesTask?.cancel()
    }

    /// App-owned listeners remain live after unverified, expired, upgraded or revoked events.
    public func startMonitoringEntitlements() {
        guard subscriptionMonitorTask == nil else { return }
        let updates = entitlementClient.updates(subscriptionProductIDs)
        subscriptionMonitorTask = Task { @MainActor [weak self] in
            for await update in updates {
                guard !Task.isCancelled else { break }
                await self?.reconcileEntitlements(waitForExternal: false)
                guard !Task.isCancelled else { break }
                await update.finish?()
            }
            self?.subscriptionMonitorTask = nil
        }
    }

    /// Keep account ownership current even when no reader window is mounted.
    /// Session publishes its causal snapshot before its separate UI properties.
    public func observeExternalSubscriptionAccount(_ session: Session) {
        guard externalAccountObservation == nil else { return }
        externalAccountObservation = session.$observedAccountSessionSnapshot
            .removeDuplicates()
            .sink { [weak self, weak session] snapshot in
                guard let self, let session,
                      snapshot == session.accountSessionSnapshot else { return }
                invalidateExternalSubscription()
                guard snapshot.identity != .transitioning else { return }
                resumeExternalSubscription()
                Task { @MainActor [weak self, weak session] in
                    guard let self, let session,
                          snapshot == session.accountSessionSnapshot else { return }
                    await reconcileEntitlements()
                }
            }
    }

    /// Retire every result captured under the previous Manabi account immediately.
    /// Apple ownership is independent of the Manabi account and is rechecked normally.
    public func invalidateExternalSubscription() {
        externalSubscriptionGeneration &+= 1
        externalSubscriptionTask?.cancel()
        externalRefreshPending = false
        externalSubscriptionEnabled = false
        externalEntitlementState = hasExternalSubscriptionProvider ? .checking : .inactive
        // Changing the Manabi account neither invalidates a verified Apple grant
        // nor retires the Apple read already in flight.
        publishCombinedEntitlementState()
        notifyReconciliationWaiters()
    }

    /// Call once the account transition has settled; observation during a transition
    /// must not query the credentials belonging to the departing account.
    public func resumeExternalSubscription() {
        externalSubscriptionEnabled = true
    }

    /// Compatibility for existing onboarding clients. Product metadata is deliberately unused.
    public func refreshIsSubscribed(storeHelper: StoreHelper) {
        Task { @MainActor [weak self] in await self?.reconcileEntitlements() }
    }

    public func reconcileEntitlements() async {
        await reconcileEntitlements(waitForExternal: true)
    }

    private func reconcileEntitlements(waitForExternal: Bool) async {
        subscriptionRefreshGeneration &+= 1
        let generation = subscriptionRefreshGeneration
        externalSubscriptionGeneration &+= 1
        let externalGeneration = externalSubscriptionGeneration
        subscriptionRefreshTask?.cancel()
        externalSubscriptionTask?.cancel()
        // Keep the last StoreKit result while revalidating. Pending work is tracked
        // separately, and the new snapshot (including empty/error) replaces it.
        let shouldCheckExternal = externalSubscriptionEnabled && hasExternalSubscriptionProvider
        // Account observation retires grants at identity boundaries. An ordinary
        // refresh must retain a confirmed grant until its fresh result replaces it.
        if !hasExternalSubscriptionProvider {
            externalEntitlementState = .inactive
        }
        appleRefreshPending = true
        externalRefreshPending = shouldCheckExternal
        publishCombinedEntitlementState()
        notifyReconciliationWaiters()
        let appleTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.readAppleEntitlements(generation: generation)
        }
        // Keep the Apple observer independent of a slow Manabi backend. Both
        // completions are fenced, including callbacks that ignore cancellation.
        subscriptionRefreshTask = appleTask
        if shouldCheckExternal {
            externalSubscriptionTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.readExternalEntitlement(generation: externalGeneration)
            }
        } else {
            externalSubscriptionTask = nil
        }
        // Wait on state transitions rather than Task.value: cancellation does not
        // unblock a provider that ignores it. A newer reconciliation must be able
        // to release Restore immediately even while an obsolete request is stuck.
        while !Task.isCancelled && isReconciliationPending(waitForExternal: waitForExternal) {
            let waiterID = UUID()
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    if Task.isCancelled {
                        continuation.resume()
                    } else {
                        reconciliationWaiters[waiterID] = continuation
                    }
                }
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.reconciliationWaiters.removeValue(forKey: waiterID)?.resume()
                }
            }
        }
    }

    private func isReconciliationPending(waitForExternal: Bool) -> Bool {
        // Transaction acknowledgement waits for Apple specifically. UI callers
        // can finish as soon as either freshly checked source confirms access.
        guard waitForExternal else { return appleRefreshPending }
        if !appleRefreshPending && appleEntitlementState == .active { return false }
        if !externalRefreshPending && externalEntitlementState == .active { return false }
        return appleRefreshPending || externalRefreshPending
    }

    private func notifyReconciliationWaiters() {
        let waiters = reconciliationWaiters.values
        reconciliationWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    private func readAppleEntitlements(generation: UInt64) async {
        let state: SubscriptionEntitlementState
        do {
            let entitlements = try await entitlementClient.current()
            state = SubscriptionEntitlement.state(for: entitlements, recognizing: subscriptionProductIDs)
        } catch {
            state = .unavailable
        }
        guard generation == subscriptionRefreshGeneration, !Task.isCancelled else { return }
        appleEntitlementState = state
        appleRefreshPending = false
        publishCombinedEntitlementState()
        notifyReconciliationWaiters()
    }

    private func readExternalEntitlement(generation: UInt64) async {
        let state: SubscriptionEntitlementState
        do {
            var external = false
            if externalSubscriptionEnabled {
                #if DEBUG
                if lakeKitPretendSubscriptionEnabled {
                    external = true
                } else {
                    external = try await isSubscribedFromElsewhereCallback?(self) ?? false
                }
                #else
                external = try await isSubscribedFromElsewhereCallback?(self) ?? false
                #endif
            }
            state = external ? .active : .inactive
        } catch {
            state = .unavailable
        }
        guard generation == externalSubscriptionGeneration, !Task.isCancelled else { return }
        externalEntitlementState = state
        externalRefreshPending = false
        publishCombinedEntitlementState()
        notifyReconciliationWaiters()
    }

    private func publishCombinedEntitlementState() {
        isSubscribedFromElsewhere = externalEntitlementState == .active
        let states = [appleEntitlementState, externalEntitlementState]
        if states.contains(.active) {
            publishEntitlementState(.active)
        } else if appleRefreshPending || externalRefreshPending || states.contains(.checking) {
            publishEntitlementState(.checking)
        } else if states.contains(.unavailable) {
            publishEntitlementState(.unavailable)
        } else {
            publishEntitlementState(.inactive)
        }
    }

    private func publishEntitlementState(_ state: SubscriptionEntitlementState) {
        // Approval arrives through the entitlement listener rather than the
        // original purchase result. Retire pending so a later expiry can offer
        // resubscription instead of retaining a completed approval indefinitely.
        if state == .active, purchaseState == .pending {
            purchaseState = .purchased
        }
        entitlementState = state
        AdsViewModel.shared.showAds = showAds
        AdsViewModel.shared.isInitialized = isInitialized
    }

    /// All callers join one synchronization and receive its completed error,
    /// independent of any subsequent restore changing the published UI state.
    @discardableResult
    public func restorePurchases() async -> String? {
        if let restorePurchasesTask { return await restorePurchasesTask.value }
        isRestoringPurchases = true
        restorePurchasesError = nil
        let task = Task { @MainActor [weak self] () -> String? in
            guard let self else { return nil }
            let error = await synchronizePurchases()
            restorePurchasesError = error
            isRestoringPurchases = false
            restorePurchasesTask = nil
            return error
        }
        restorePurchasesTask = task
        return await task.value
    }

    private func synchronizePurchases() async -> String? {
        do {
            try await entitlementClient.sync()
            await reconcileEntitlements()
            switch entitlementState {
            case .active:
                return nil
            case .inactive:
                return "No active Premium subscription was found. Check that you’re using the App Store account that made the purchase, then try again."
            case .unavailable:
                return "Your purchases were synchronized, but Premium access could not be verified. Please try again."
            case .checking:
                return "Your purchases were synchronized, but Premium verification was interrupted by an account change. Please wait for your account to finish updating, then try again."
            }
        } catch {
            return error.localizedDescription
        }
    }

}

public struct StoreProduct: Identifiable {
    public let id: String
    
    public let isSubscription: Bool
    public let unitsRemaining: Int?
    public let unitsPurchased: Int?
    public let unitsName: String?
    
    public let iconSymbolName: String
    public let buyButtonTitle: String?
    public let badgeText: String?
    
    public let filterPurchase: ((StoreProduct) -> Bool)
    
    public init(
        id: String,
        isSubscription: Bool,
        unitsRemaining: Int? = nil,
        unitsPurchased: Int? = nil,
        unitsName: String? = nil,
        iconSymbolName: String,
        buyButtonTitle: String? = nil,
        badgeText: String? = nil,
        filterPurchase: @escaping ((StoreProduct) -> Bool) = { _ in return true }
    ) {
        self.id = id
        self.isSubscription = isSubscription
        self.unitsRemaining = unitsRemaining
        self.unitsPurchased = unitsPurchased
        self.unitsName = unitsName
        self.iconSymbolName = iconSymbolName
        self.buyButtonTitle = buyButtonTitle
        self.badgeText = badgeText
        self.filterPurchase = filterPurchase
    }
    
    func product(storeHelper: StoreHelper) -> Product? {
        return storeHelper.product(from: id)
    }
}

public struct StoreProductVersions: Identifiable {
    public let product: StoreProduct
    public let referralProduct: StoreProduct
    
    public var id: String {
        return product.id
    }
    
    public enum StoreProductVersion {
        case product
        case referralProduct
    }
    
    public init(
        product: StoreProduct,
        referralProduct: StoreProduct
    ) {
        self.product = product
        self.referralProduct = referralProduct
    }
    
    func product(version: StoreProductVersion, storeHelper: StoreHelper) -> Product? {
        let product: StoreProduct
        switch version {
        case .product:
            product = self.product
        case .referralProduct:
            product = referralProduct
        }
        return storeHelper.product(from: product.id)
    }
}
