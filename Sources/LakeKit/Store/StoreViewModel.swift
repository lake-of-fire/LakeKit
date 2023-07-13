import SwiftUI
import Collections
import StoreHelper

public class StoreViewModel: NSObject, ObservableObject {
    /// For server overrides, other apps, etc.
    @Published public var isSubscribed = false
    @Published public var isSubscribedFromElsewhere = false
    @Published public var isInitialized = false
    
    let satisfyingPrerequisite: () async -> Bool
    @Published public var products: [StoreProduct]
    @Published public var studentProducts: [StoreProduct]
    @Published public var appAccountToken: UUID?
    @Published public var headline: String
    @Published public var subheadline: String
    @Published public var productGroupHeading: String
    @Published public var productGroupSubtitle: String = ""
    @Published public var freeTierExplanation: String?
    @Published public var benefits: [String]
    @Published public var termsOfService: URL
    @Published public var privacyPolicy: URL
    @Published public var chatURL: URL? = nil
    @Published public var faq = OrderedDictionary<String, String>()
    
    @MainActor var beforeSubscriptionRefresh: ((StoreViewModel) async -> Void)? = nil
    private var subscriptionRefreshTask: Task<Void, Never>? = nil
    
    public init(satisfyingPrerequisite: @escaping () async -> Bool = { true }, products: [StoreProduct], studentProducts: [StoreProduct], appAccountToken: UUID? = nil, headline: String, subheadline: String, productGroupHeading: String, productGroupSubtitle: String = "", freeTierExplanation: String? = nil, benefits: [String], termsOfService: URL, privacyPolicy: URL, chatURL: URL? = nil, faq: OrderedDictionary<String, String>, beforeSubscriptionRefresh: ((StoreViewModel) async -> Void)? = nil) {
        self.satisfyingPrerequisite = satisfyingPrerequisite
        self.products = products
        self.studentProducts = studentProducts
        self.appAccountToken = appAccountToken
        self.headline = headline
        self.subheadline = subheadline
        self.productGroupHeading = productGroupHeading
        self.productGroupSubtitle = productGroupSubtitle
        self.freeTierExplanation = freeTierExplanation
        self.benefits = benefits
        self.termsOfService = termsOfService
        self.privacyPolicy = privacyPolicy
        self.chatURL = chatURL
        self.faq = faq
        self.beforeSubscriptionRefresh = beforeSubscriptionRefresh
    }
    
    public var productGridColumns: [GridItem] {
        return [GridItem(.adaptive(minimum: 200), spacing: 20)]
    }
    
    public var showAds: Bool {
        return !isSubscribed && isInitialized
    }
    
    @MainActor
    public func refreshIsSubscribed(storeHelper: StoreHelper) {
        subscriptionRefreshTask?.cancel()
        subscriptionRefreshTask = Task { @MainActor in
            do {
                try Task.checkCancellation()
                if ProcessInfo.processInfo.arguments.contains("pretend-subscribed"), !isSubscribedFromElsewhere {
                    isSubscribedFromElsewhere = true
                    print("HUH is subbed from else")
                }
                
                if let beforeSubscriptionRefresh = beforeSubscriptionRefresh {
                    print("HUH before..")
                    await beforeSubscriptionRefresh(self)
                } else {
                    print("HUH NO before..")
                }
                
                if isSubscribedFromElsewhere {
                    try Task.checkCancellation()
                    if !isSubscribed {
                        isSubscribed = true
                    }
                    isInitialized = true
                    print("HUH ret cos good")
                    return
                }
                
                //            for product in (storeHelper.subscriptionProducts ?? []) {
                //                if let groupName = storeHelper.subscriptionHelper.groupName(from: product.id), let state = await storeHelper.subscriptionHelper.subscriptionInfo(for: groupName)?.subscriptionStatus?.state {
                //                    print(state)
                //                    isSubscribed = state == .inBillingRetryPeriod || state == .inGracePeriod || state == .subscribed
                //                }
                //            }
                //            isSubscribed = false
                guard let group = await storeHelper.subscriptionHelper.groupSubscriptionInfo()?.first, let groupID = group.subscriptionGroup, let subscriptionState = await storeHelper.subscriptionHelper.subscriptionInfo(for: groupID)?.subscriptionStatus?.state else {
                    try Task.checkCancellation()
                    isSubscribed = false
                    isInitialized = true
                    print("HUH undoing it! no sub")
                    return
                }
                
                try Task.checkCancellation()
                isSubscribed = subscriptionState == .inBillingRetryPeriod || subscriptionState == .inGracePeriod || subscriptionState == .subscribed
                isInitialized = true
                    print("HUH sub cuz good")
            } catch {
            }
        }
    }
}
