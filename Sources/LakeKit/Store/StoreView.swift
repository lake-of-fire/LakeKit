import SwiftUI
import StoreHelper
import StoreKit
import Collections

public extension View {
    func storeSheet(isPresented: Binding<Bool>, storeViewModel: StoreViewModel) -> some View {
        self.modifier(StoreSheetModifier(isPresented: isPresented, storeViewModel: storeViewModel))
    }
}

public struct StoreSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @ObservedObject public var storeViewModel: StoreViewModel

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
#if os(iOS)
                NavigationView {
                    StoreView(storeViewModel: storeViewModel)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel", role: .cancel) {
                                    isPresented = false
                                }
                            }
                        }
                        .navigationBarTitleDisplayMode(.inline)
                }
                .navigationViewStyle(.stack)
#else
                StoreView(storeViewModel: storeViewModel)
                    .padding(.top, 10)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel", role: .cancel) {
                                isPresented = false
                            }
                        }
                    }
                .frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 760)
#endif
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
        .multilineTextAlignment(.leading)
        .onTapGesture(count: 1) {
            withAnimation { isExpanded.toggle() }
        }
    }
}

struct StudentDiscountDisclosureGroup<Content: View>: View {
    let discountView: Content
    
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            discountView
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(Image(systemName: "info.circle"))
                    .font(.title)
                    .padding(.trailing, 5)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Are you a student or educator? A special discount is available to you.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Student & Educator Discount \(Image(systemName: "chevron.right"))")
                    .font(.headline)
                    .bold()
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onTapGesture(count: 1) {
            withAnimation { isExpanded.toggle() }
        }
    }
    
    public init(discountView contentBuilder: () -> Content) {
        discountView = contentBuilder()
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
    
    public let filterPurchase: ((StoreProduct) -> Bool)
    
    public init(id: String, isSubscription: Bool, unitsRemaining: Int? = nil, unitsPurchased: Int? = nil, unitsName: String? = nil, iconSymbolName: String, buyButtonTitle: String? = nil, filterPurchase: @escaping ((StoreProduct) -> Bool) = { _ in return true } ) {
        self.id = id
        self.isSubscription = isSubscription
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
    
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    
    @EnvironmentObject private var storeHelper: StoreHelper
    @State private var purchaseState: PurchaseState = .unknown
    @State private var isPresentingTokenLimitError = false

    public var productGridColumns: [GridItem] {
#if os(iOS)
        if horizontalSizeClass == .compact {
            return [GridItem(.adaptive(minimum: 200), spacing: 20)]
        }
#endif
        return [GridItem(.adaptive(minimum: 200), spacing: 20), GridItem(.adaptive(minimum: 200), spacing: 20)]
    }
    
    var secondaryHorizontalPadding: CGFloat {
#if os(iOS)
        return horizontalSizeClass == .compact ? 0 : 40
#else
        return 40
#endif
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
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
                        .padding(.top, 5)
                }
                
                LazyVGrid(columns: productGridColumns, spacing: 10) {
                    ForEach(storeViewModel.products) { (storeProduct: StoreProduct) in
                        if let product = storeProduct.product(storeHelper: storeHelper) {
                            productOptionView(storeProduct: storeProduct, product: product)
//                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: .infinity)
                            //                            .fixedSize(horizontal: false, vertical: true)
                            //                            .frame(maxWidth: .infinity)
                        }
                    }
                }
//                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, secondaryHorizontalPadding)
                
                GroupBox {
                    StudentDiscountDisclosureGroup(discountView: {
                        VStack {
                            Text("Students and educators already have enough expenses to manage for which we'd like to help ease the burden. If you're not eligible, please use the regular rate options to provide support to the developers for ongoing app improvements.")
                                .font(.subheadline)
                                .padding()
                            
                            LazyVGrid(columns: productGridColumns, spacing: 10) {
                                ForEach(storeViewModel.studentProducts) { (storeProduct: StoreProduct) in
                                    if let product = storeProduct.product(storeHelper: storeHelper) {
                                        productOptionView(storeProduct: storeProduct, product: product)
                                            .frame(maxHeight: .infinity)
                                    }
                                }
                            }
                            //                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.top, 5)
                    })
                }
                
                Text(storeViewModel.productGroupSubtitle)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(storeViewModel.benefits, id: \.self) { benefit in
                        Text(Image(systemName: "checkmark.circle"))
                            .bold()
                            .foregroundColor(.green)
                        + Text(" ") + Text(.init(benefit))
                    }
                }
                .font(.callout)
                .padding(.horizontal, secondaryHorizontalPadding)
                
                HStack(spacing: 20) {
                    Link("Terms of Service", destination: storeViewModel.termsOfService)
                    Divider()
                    Link("Privacy Policy", destination: storeViewModel.privacyPolicy)
                }
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                
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
                    .padding(10)
                }
                .padding(.top, 10)
                Spacer()
            }
            .padding([.leading, .trailing, .bottom])
            .frame(idealWidth: storeWidth, minHeight: storeHeight)
        }
    }
    
    public init(storeViewModel: StoreViewModel) {
        self.storeViewModel = storeViewModel
    }
    
    func productOptionView(storeProduct: StoreProduct, product: Product) -> some View {
        let priceViewModel = PriceViewModel(storeHelper: storeHelper, purchaseState: $purchaseState)
        return PurchaseOptionView(storeViewModel: storeViewModel, product: product, purchaseState: $purchaseState, unitsRemaining: storeProduct.unitsRemaining, unitsPurchased: storeProduct.unitsPurchased, unitsName: storeProduct.unitsName, symbolName: storeProduct.iconSymbolName, buyTitle: storeProduct.buyButtonTitle) {
            guard storeProduct.filterPurchase(storeProduct) else { return }
            purchaseState = .inProgress
            Task {
                if let appAccountToken = storeViewModel.appAccountToken {
                    await priceViewModel.purchase(product: product, options: [.appAccountToken(appAccountToken)])
                } else {
                    await priceViewModel.purchase(product: product, options: [])
                }
            }
        }
        .modifier {
#if os(iOS)
            if horizontalSizeClass == .compact {
                $0.frame(maxWidth: .infinity)
            } else { $0 }
#else
            $0
#endif
        }
//            .frame(maxHeight: .infinity)
            //                            .fixedSize(horizontal: false, vertical: true)
            //                            .frame(maxWidth: .infinity)
        }
    }
