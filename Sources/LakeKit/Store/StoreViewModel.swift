import SwiftUI
import Collections
import StoreHelper

public class AdsViewModel: NSObject, ObservableObject {
    public static var shared = AdsViewModel()
    
    @Published public var showAds = false
}

public class StoreViewModel: NSObject, ObservableObject {
    /// For server overrides, other apps, etc.
    @Published public var isInitialized = false
    
    @Published public var isRestoringPurchases = false
    
    let satisfyingPrerequisite: () async -> Bool
    let highlightedProductID: String
    @Published public var products: [StoreProduct]
    @Published public var studentProducts: [StoreProduct]
    @Published public var appAccountToken: UUID?
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
    
    @PublishedAppStorage("LakeKit.isSubscribed") public var isSubscribed = false
    @PublishedAppStorage("LakeKit.isSubscribedFromElsewhere") public var isSubscribedFromElsewhere = false
    @MainActor var isSubscribedFromElsewhereCallback: ((StoreViewModel) async -> Bool)? = nil
    private var subscriptionRefreshTask: Task<Void, Never>? = nil
    
    public init(satisfyingPrerequisite: @escaping () async -> Bool = { true }, products: [StoreProduct], studentProducts: [StoreProduct], highlightedProductID: String, appAccountToken: UUID? = nil, headline: String, subheadline: String, productGroupHeading: String, productGroupSubtitle: String?, freeTierExplanation: String? = nil, testimonialTitle: String?, testimonialImage: Image?,  testimonial: String, testimonialLink: URL?, benefits: [String], termsOfService: URL, privacyPolicy: URL, chatURL: URL? = nil, faq: OrderedDictionary<String, String>, isSubscribedFromElsewhereCallback: ((StoreViewModel) async -> Bool)? = nil) {
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
                    return
                }
                
                if !isSubscribed {
                    isSubscribed = true
                }
                if !isInitialized {
                    isInitialized = true
                }
                
                AdsViewModel.shared.showAds = showAds
            } catch {
                print(error)
                if (error as? CancellationError) == nil {
                    Logger.shared.logger.error("\(error)")
                }
            }
        }
    }
}
