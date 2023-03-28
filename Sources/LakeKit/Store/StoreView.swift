import SwiftUI
import StoreHelper
import StoreKit
import Collections

public extension View {
    func storeSheet(storeViewModel: StoreViewModel) -> some View {
        self.modifier(StoreSheetModifier(storeViewModel: storeViewModel))
    }
}

public struct StoreSheetModifier: ViewModifier {
    @ObservedObject public var storeViewModel: StoreViewModel

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $storeViewModel.isPresentingStoreSheet) {
                NavigationView {
                    StoreView(storeViewModel: storeViewModel)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel", role: .cancel) {
                                    storeViewModel.isPresentingStoreSheet = false
                                }
                            }
                        }
                }
            }
    }
}

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
    @ObservedObject public var storeViewModel: StoreViewModel
    
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
                    Text(storeViewModel.headline)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Text(storeViewModel.subheadline)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Text(storeViewModel.productGroupHeading)
                        .foregroundColor(.secondary)
                        .bold()
                        .multilineTextAlignment(.center)
                }
                
                HStack(alignment: .top, spacing: 12) {
                    ForEach(storeViewModel.products) { (product: StoreProduct) in
                        if let storeProduct = product.product(storeHelper: storeHelper) {
                            PurchaseOptionView(product: storeProduct, purchaseState: $purchaseState, unitsRemaining: product.unitsRemaining, unitsPurchased: product.unitsPurchased, unitsName: product.unitsName, symbolName: product.iconSymbolName, buyTitle: product.buyButtonTitle) {
                                guard product.filterPurchase(product) else { return }
                                
                                purchaseState = .inProgress
                                Task {
                                    if let appAccountToken = storeViewModel.appAccountToken {
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
                Text(storeViewModel.productGroupSubtitle)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .font(.caption)
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Q&A")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        ForEach(storeViewModel.faq.elements, id: \.key) { q, a in
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
    
    public init(storeViewModel: StoreViewModel) {
        self.storeViewModel = storeViewModel
    }
}
