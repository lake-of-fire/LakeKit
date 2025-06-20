import SwiftUI
import Collections
import StoreKit
import StoreHelper

public class AdsViewModel: NSObject, ObservableObject {
    public static var shared = AdsViewModel()
    
    @Published public var isInitialized = false
    @Published public var showAds = false
}

public class StoreViewModel: NSObject, ObservableObject {
    /// Validates a referral code asynchronously. Returns true if valid.
    let validateReferralCode: (String) async throws -> Bool
    let processReferralCodeUse: (String, String) async throws -> Void
    /// For server overrides, other apps, etc.
    @Published public var isInitialized = false
    
    @Published public var isRestoringPurchases = false
    
    let satisfyingPrerequisite: () async -> Bool
    
    let highlightedProductID: String
    @Published public var products: [StoreProductVersions]
    @Published public var studentProducts: [StoreProductVersions]
    
    let appAccountToken: () async -> UUID?
    @Published public var headline: String
    @Published public var subheadline: String
    @Published public var productGroupHeading: String
    @Published public var productGroupSubtitle: String?
    @Published public var freeTierExplanation: String?
    @Published public var testimonialTitle: String?
    @Published public var testimonialImage: Image?
    @Published public var testimonial: String?
    @Published public var testimonialLink: URL?
    @Published public var benefits: [String]
    @Published public var termsOfService: URL
    @Published public var privacyPolicy: URL
    @Published public var chatURL: URL? = nil
    @Published public var faq = OrderedDictionary<String, String>()
    
    @Published public var purchaseState: PurchaseState = .unknown
    
    @AppStorage("pendingReferralCode") private var pendingReferralCode: String?
    @PublishedAppStorage("LakeKit.isSubscribed") public var isSubscribed = false
    @PublishedAppStorage("LakeKit.isSubscribedFromElsewhere") public var isSubscribedFromElsewhere = false
    @MainActor var isSubscribedFromElsewhereCallback: ((StoreViewModel) async -> Bool)? = nil
    private var subscriptionRefreshTask: Task<Void, Never>? = nil
    
    public init(
        satisfyingPrerequisite: @escaping () async -> Bool = { true },
        products: [StoreProductVersions],
        studentProducts: [StoreProductVersions],
        highlightedProductID: String,
        appAccountToken: @escaping () async -> UUID? = { nil },
        headline: String,
        subheadline: String,
        productGroupHeading: String,
        productGroupSubtitle: String?,
        freeTierExplanation: String? = nil,
        testimonialTitle: String?,
        testimonialImage: Image?,
        testimonial: String,
        testimonialLink: URL?,
        benefits: [String],
        termsOfService: URL,
        privacyPolicy: URL,
        chatURL: URL? = nil,
        faq: OrderedDictionary<String, String>,
        isSubscribedFromElsewhereCallback: ((StoreViewModel) async -> Bool)? = nil,
        validateReferralCode: @escaping (String) async throws -> Bool = { _ in false },
        processReferralCodeUse: @escaping (String, String) async throws -> Void = { _, _ in }
    ) {
        self.satisfyingPrerequisite = satisfyingPrerequisite
        self.products = products
        self.studentProducts = studentProducts
        self.highlightedProductID = highlightedProductID
        self.appAccountToken = appAccountToken
        self.headline = headline
        self.subheadline = subheadline
        self.productGroupHeading = productGroupHeading
        self.productGroupSubtitle = productGroupSubtitle
        self.freeTierExplanation = freeTierExplanation
        self.testimonialTitle = testimonialTitle
        self.testimonialImage = testimonialImage
        self.testimonial = testimonial
        self.testimonialLink = testimonialLink
        self.benefits = benefits
        self.termsOfService = termsOfService
        self.privacyPolicy = privacyPolicy
        self.chatURL = chatURL
        self.faq = faq
        self.isSubscribedFromElsewhereCallback = isSubscribedFromElsewhereCallback
        self.validateReferralCode = validateReferralCode
        self.processReferralCodeUse = processReferralCodeUse
    }
    
    public var productGridColumns: [GridItem] {
        return [GridItem(.adaptive(minimum: 200), spacing: 20)]
    }
    
    public var showAds: Bool {
        return !isSubscribed && isInitialized
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
            if let appAccountToken = await appAccountToken() {
                await priceViewModel.purchase(product: storeKitProduct, options: [.appAccountToken(appAccountToken)])
            } else {
                await priceViewModel.purchase(product: storeKitProduct, options: [])
            }
            
            await processPendingReferralCodeIfNeeded()
        }
    }
    
    /// Attempts to process a pending referral code by attaching it to the latest App Store receipt.
    /// - Note: `processReferralCodeUse` expects **(receipt, referralCode)** in that order.
    @MainActor
    public func processPendingReferralCodeIfNeeded() async {
        guard let code = pendingReferralCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else { return }
        do {
            // Get the original transaction ID for any active entitlement
            var originalTransactionID: String? = nil
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    originalTransactionID = String(transaction.originalID)
                    break
                }
            }
            
            // Grab the up-to-date unified receipt for the app
            guard let receiptURL = Bundle.main.appStoreReceiptURL,
                  let receiptData = try? Data(contentsOf: receiptURL),
                  !receiptData.isEmpty else { return }
            let receiptBase64 = receiptData.base64EncodedString()
            
            // Log a warning if referral code is attached to an existing transaction
            if let originalTransactionID {
                Logger.shared.logger.warning("Attaching referral code \(code) to transaction \(originalTransactionID)")
            }
            
            // Send the receipt + referral code to the backend
            try await processReferralCodeUse(receiptBase64, code)
            
            // Clear the referral code only if the call succeeded
            pendingReferralCode = nil
        } catch {
            Logger.shared.logger.error("Failed to process pending referral code \(code): \(error)")
        }
    }
    
    @MainActor
    public func refreshIsSubscribed(storeHelper: StoreHelper) {
        subscriptionRefreshTask?.cancel()
        subscriptionRefreshTask = Task { @MainActor in
            do {
                try Task.checkCancellation()
                //#if DEBUG
                //                isSubscribedFromElsewhere = true
                //#else
                if ProcessInfo.processInfo.arguments.contains("pretend-subscribed"), !isSubscribedFromElsewhere {
                    isSubscribedFromElsewhere = true
                } else if let isSubscribedFromElsewhereCallback = isSubscribedFromElsewhereCallback {
                    let isSubscribedFromElsewhere = await isSubscribedFromElsewhereCallback(self)
                    if isSubscribedFromElsewhere != self.isSubscribedFromElsewhere {
                        self.isSubscribedFromElsewhere = isSubscribedFromElsewhere
                    }
                }
                //#endif
                
                if isSubscribedFromElsewhere {
                    try Task.checkCancellation()
                    if !isSubscribed {
                        isSubscribed = true
                    }
                    if !isInitialized {
                        isInitialized = true
                    }
                    AdsViewModel.shared.showAds = showAds
                    AdsViewModel.shared.isInitialized = true
                    
                    await processPendingReferralCodeIfNeeded()
                    
                    return
                }
                
                //            for product in (storeHelper.subscriptionProducts ?? []) {
                //                if let groupName = storeHelper.subscriptionHelper.groupName(from: product.id), let state = await storeHelper.subscriptionHelper.subscriptionInfo(for: groupName)?.subscriptionStatus?.state {
                //                    print(state)
                //                    isSubscribed = state == .inBillingRetryPeriod || state == .inGracePeriod || state == .subscribed
                //                }
                //            }
                //            isSubscribed = false
                let allSubscriptionProductIDs = storeHelper.productIds
                
                guard try await (storeHelper.productIds ?? []).async.contains(where: {
                    try await storeHelper.isPurchased(productId: $0)
                }) else {
                    try Task.checkCancellation()
                    if isSubscribed {
                        isSubscribed = false
                    }
                    if !isInitialized {
                        isInitialized = true
                    }
                    AdsViewModel.shared.showAds = showAds
                    AdsViewModel.shared.isInitialized = true
                    return
                }
                
                if !isSubscribed {
                    isSubscribed = true
                }
                if !isInitialized {
                    isInitialized = true
                }
                
                AdsViewModel.shared.showAds = showAds
                AdsViewModel.shared.isInitialized = true
                
                await processPendingReferralCodeIfNeeded()
            } catch (let error as CancellationError) {
                print(error)
            } catch {
                print(error)
                if (error as? CancellationError) == nil {
                    Logger.shared.logger.error("\(error)")
                }
            }
        }
    }
}
