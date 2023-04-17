import SwiftUI
import Collections
import StoreHelper

public class StoreViewModel: NSObject, ObservableObject {
    /// For server overrides, other apps, etc.
    @Published public var isSubscribed = false
    @Published public var isSubscribedFromElsewhere = false
    
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
    @Published public var faq = OrderedDictionary<String, String>()
    
    public init(satisfyingPrerequisite: @escaping () async -> Bool = { true }, products: [StoreProduct], studentProducts: [StoreProduct], appAccountToken: UUID? = nil, headline: String, subheadline: String, productGroupHeading: String, productGroupSubtitle: String = "", freeTierExplanation: String? = nil, benefits: [String], termsOfService: URL, privacyPolicy: URL, faq: OrderedDictionary<String, String>) {
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
        self.faq = faq
    }
    
    public var productGridColumns: [GridItem] {
        return [GridItem(.adaptive(minimum: 200), spacing: 20)]
    }
    
    public func refreshIsSubscribed(storeHelper: StoreHelper) {
        Task { @MainActor in
            if isSubscribedFromElsewhere {
                isSubscribed = true
                return
            }
            guard let group = await storeHelper.subscriptionHelper.groupSubscriptionInfo()?.first, let groupID = group.subscriptionGroup, let subscriptionState = await storeHelper.subscriptionHelper.subscriptionInfo(for: groupID)?.subscriptionStatus?.state else {
                isSubscribed = false
                return
            }
            isSubscribed = subscriptionState == .inBillingRetryPeriod || subscriptionState == .inGracePeriod || subscriptionState == .subscribed
        }
    }
}
