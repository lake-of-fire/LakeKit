import SwiftUI
import Collections

public class StoreViewModel: NSObject, ObservableObject {
    @Published public var isPresentingStoreSheet = false
    
    /// For server overrides, other apps, etc.
    @Published public var isSubscribedFromElsewhere = false
    
    @Published public var products: [StoreProduct]
    @Published public var studentProducts: [StoreProduct]
    @Published public var appAccountToken: UUID?
    @Published public var headline: String
    @Published public var subheadline: String
    @Published public var productGroupHeading: String
    @Published public var productGroupSubtitle: String = ""
    @Published public var faq = OrderedDictionary<String, String>()
    
    public init(products: [StoreProduct], studentProducts: [StoreProduct], appAccountToken: UUID? = nil, headline: String, subheadline: String, productGroupHeading: String, productGroupSubtitle: String = "", faq: OrderedDictionary<String, String>) {
        self.products = products
        self.studentProducts = studentProducts
        self.appAccountToken = appAccountToken
        self.headline = headline
        self.subheadline = subheadline
        self.productGroupHeading = productGroupHeading
        self.productGroupSubtitle = productGroupSubtitle
        self.faq = faq
    }
    
}
