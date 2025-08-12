import SwiftUI
import OrderedCollections
import StoreKit
import StoreHelper

@MainActor
public class AdsViewModel: NSObject, ObservableObject {
    public static var shared = AdsViewModel()
    
    @Published public var isInitialized = false
    @Published public var showAds = false
}

@MainActor
public class StoreViewModel: NSObject, ObservableObject {
    /// Validates and reserves  a referral code asynchronously.
    let reserveReferralCodeForPurchase: (String, UUID) async throws -> Void
    /// For server overrides, other apps, etc.
    @Published public var isInitialized = false
    
    @Published public var isRestoringPurchases = false
    
    let satisfyingPrerequisite: () async -> Bool
    
    let highlightedProductID: String
    @Published public var products: [StoreProductVersions]
    @Published public var studentProducts: [StoreProductVersions]
    
    @Published public var headline: String
    @Published public var subheadline: String
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
    @PublishedAppStorage("LakeKit.isSubscribed") public var isSubscribed = false
    @PublishedAppStorage("LakeKit.isSubscribedFromElsewhere") public var isSubscribedFromElsewhere = false
    @MainActor var isSubscribedFromElsewhereCallback: ((StoreViewModel) async -> Bool)? = nil
    private var subscriptionRefreshTask: Task<Void, Never>? = nil
    
    public init(
        satisfyingPrerequisite: @escaping () async -> Bool = { true },
        products: [StoreProductVersions],
        studentProducts: [StoreProductVersions],
        highlightedProductID: String,
        headline: String,
        subheadline: String,
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
        isSubscribedFromElsewhereCallback: ((StoreViewModel) async -> Bool)? = nil,
        reserveReferralCodeForPurchase: @escaping (String, UUID) async throws -> Void = { _, _ in }
    ) {
        self.satisfyingPrerequisite = satisfyingPrerequisite
        self.products = products
        self.studentProducts = studentProducts
        self.highlightedProductID = highlightedProductID
        self.headline = headline
        self.subheadline = subheadline
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
            let appAccountToken = Self.getOrCreateAppAccountToken()
            await priceViewModel.purchase(product: storeKitProduct, options: [
                .appAccountToken(appAccountToken),
            ])
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
