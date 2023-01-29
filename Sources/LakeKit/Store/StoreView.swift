import SwiftUI
import StoreHelper
import StoreKit
import Collections

struct FAQDisclosureGroup: View {
    let question: String
    let answer: String
    
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(answer)
                .font(.body)
                .foregroundColor(.secondary)
        } label: {
            Text("\(question)")
                .font(.headline)
                .bold()
        }
        .onTapGesture(count: 1) {
            withAnimation { isExpanded.toggle() }
        }
    }
}

public struct StoreProduct: Identifiable {
    public let id: String
    
    public let unitsRemaining: Int?
    public let unitsPurchased: Int?
    public let unitsName: String?
    
    public let iconSymbolName: String
    public let buyButtonTitle: String
    
    public let filterPurchase: ((StoreProduct) -> Bool)
    
    public init(id: String, unitsRemaining: Int? = nil, unitsPurchased: Int? = nil, unitsName: String? = nil, iconSymbolName: String, buyButtonTitle: String, filterPurchase: @escaping ((StoreProduct) -> Bool) = { _ in return true } ) {
        self.id = id
        self.unitsRemaining = unitsRemaining
        self.unitsPurchased = unitsPurchased
        self.unitsName = unitsName
        self.iconSymbolName = iconSymbolName
        self.buyButtonTitle = buyButtonTitle
        self.filterPurchase = filterPurchase
    }

    func product(storeHelper: StoreHelper) -> Product? {
        return storeHelper.product(from: id)
    }
}

public struct StoreView: View {
    public let products: [StoreProduct]
    public let appAccountToken: UUID?
    public let headline: String
    public let subheadline: String
    public let productGroupHeading: String
    public var productGroupSubtitle: String = ""
    public var faq = OrderedDictionary<String, String>()
    
    @ScaledMetric(relativeTo: .title2) private var storeWidth = 666
    @ScaledMetric(relativeTo: .title2) private var storeHeight = 590
    
    @EnvironmentObject private var storeHelper: StoreHelper
    @State private var purchaseState: PurchaseState = .unknown
    @State private var isPresentingTokenLimitError = false

    public var body: some View {
        let priceViewModel = PriceViewModel(storeHelper: storeHelper, purchaseState: $purchaseState)
        
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 16) {
                    Text(headline)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.primary)
                    Text(subheadline)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                    Text(productGroupHeading)
                        .foregroundColor(.secondary)
                        .bold()
                        .multilineTextAlignment(.center)
                }
                
                HStack(alignment: .top, spacing: 12) {
                    ForEach(products) { (product: StoreProduct) in
                        if let storeProduct = product.product(storeHelper: storeHelper) {
                            PurchaseOptionView(product: storeProduct, purchaseState: $purchaseState, unitsRemaining: product.unitsRemaining, unitsPurchased: product.unitsPurchased, unitsName: product.unitsName, symbolName: product.iconSymbolName, buyTitle: product.buyButtonTitle) {
                                guard product.filterPurchase(product) else { return }
                                
                                purchaseState = .inProgress
                                Task {
                                    if let appAccountToken = appAccountToken {
                                        await priceViewModel.purchase(product: storeProduct, options: [.appAccountToken(appAccountToken)])
                                    } else {
                                        await priceViewModel.purchase(product: storeProduct, options: [])
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 42)
                Text(productGroupSubtitle)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .font(.caption)
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Questions & Answers")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        ForEach(faq.elements, id: \.key) { q, a in
                            FAQDisclosureGroup(question: q, answer: a)
                        }
                    }
                    .padding()
                }
                Spacer()
            }
            .padding()
            .frame(idealWidth: storeWidth, minHeight: storeHeight)
            .fixedSize(horizontal: true, vertical: true)
        }
    }
    
    public init(products: [StoreProduct], appAccountToken: UUID? = nil, headline: String, subheadline: String, productGroupHeading: String, productGroupSubtitle: String = "", faq: OrderedDictionary<String, String> = OrderedDictionary<String, String>()) {
        self.products = products
        self.appAccountToken = appAccountToken
        self.headline = headline
        self.subheadline = subheadline
        self.productGroupHeading = productGroupHeading
        self.productGroupSubtitle = productGroupSubtitle
        self.faq = faq
    }
}
