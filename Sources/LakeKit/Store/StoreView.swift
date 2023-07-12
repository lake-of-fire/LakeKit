import SwiftUI
import StoreHelper
import StoreKit
import Collections

public extension View {
    func storeSheet(isPresented: Binding<Bool>) -> some View {
        self.modifier(StoreSheetModifier(isPresented: isPresented))
    }
}

public struct StoreSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    @EnvironmentObject private var storeViewModel: StoreViewModel

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
#if os(iOS)
                NavigationView {
                    StoreView(isPresented: $isPresented, storeViewModel: storeViewModel)
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
                StoreView(isPresented: $isPresented, storeViewModel: storeViewModel)
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
            VStack {
                Text(answer)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        } label: {
            Text("\(question)")
                .font(.headline)
                .bold()
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
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
                    Text("Affordable pricing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Student & Educator Discount") // \(Image(systemName: "chevron.right"))")
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

struct FreeTierDisclosureGroup<Content: View>: View {
    let content: Content
    
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(Image(systemName: "info.circle"))
                    .font(.title)
                    .padding(.trailing, 5)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Use without payment")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Free Tier") // \(Image(systemName: "chevron.right"))")
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
    
    public init(content contentBuilder: () -> Content) {
        content = contentBuilder()
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
    @Binding public var isPresented: Bool
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
            return [GridItem(.adaptive(minimum: 150), spacing: 10)]
        }
#endif
        return [GridItem(.adaptive(minimum: 180), spacing: 5), GridItem(.adaptive(minimum: 180), spacing: 5)]
    }
    
    var secondaryHorizontalPadding: CGFloat {
#if os(iOS)
        return horizontalSizeClass == .compact ? 4 : 40
#else
        return 40
#endif
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Group {
                    Text(storeViewModel.headline)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(storeViewModel.subheadline)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Group {
                    Divider()
                        .padding(.bottom, 5)
                    Text(storeViewModel.productGroupHeading)
                        .foregroundColor(.primary)
                        .bold()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if !storeViewModel.productGroupSubtitle.isEmpty {
                        Text(storeViewModel.productGroupSubtitle)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
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
                }
                GroupBox {
                    StudentDiscountDisclosureGroup(discountView: {
                        VStack {
                            Text("Students and educators already have enough expenses to manage. We'd like to help ease the burden. If you're ineligible and can afford it, please use the regular rate options. Your subscription goes directly to the developers to support ongoing app improvements.")
                                .font(.subheadline)
                                .padding()
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            
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
                if let freeTierExplanation = storeViewModel.freeTierExplanation {
                    GroupBox {
                        FreeTierDisclosureGroup {
                            VStack {
                                Text(freeTierExplanation)
                                    .font(.subheadline)
                                    .padding()
                                    .fixedSize(horizontal: false, vertical: true)
                                // TODO: show links to other apps here too
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(storeViewModel.benefits, id: \.self) { benefit in
                        Text(Image(systemName: "checkmark.circle"))
                            .bold()
                            .foregroundColor(.green)
                        + Text(" ") + Text(.init(benefit))
                    }
                }
                .font(.callout)
                .padding(.top, 5)
                .padding(.horizontal, secondaryHorizontalPadding)
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
                if let chatURL = storeViewModel.chatURL {
                    GroupBox("Got A Question? Need Help?") {
                        HStack {
                            Spacer()
                            Link(destination: chatURL) { Label("Chat With Team", systemImage: "message.circle") }
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
                HStack(spacing: 20) {
                    Link("Terms of Service", destination: storeViewModel.termsOfService)
//                        .frame(maxWidth: .infinity)
                    Divider()
                    Link("Privacy Policy", destination: storeViewModel.privacyPolicy)
//                        .frame(maxWidth: .infinity)
                }
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                Spacer()
            }
            .padding([.leading, .trailing, .bottom])
            .frame(idealWidth: storeWidth, minHeight: storeHeight)
        }
        .onChange(of: storeViewModel.isSubscribed) { isSubscribed in
            Task { @MainActor in
                if isSubscribed {
                    isPresented = false
                }
            }
        }
    }
    
    private var productOptionFrameMaxWidth: CGFloat? {
#if os(iOS)
        if horizontalSizeClass == .compact {
            return .infinity
        } else { }
#endif
        return .infinity
    }
    
    public init(isPresented: Binding<Bool>, storeViewModel: StoreViewModel) {
        _isPresented = isPresented
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
        .tint(.accentColor)
        .frame(maxWidth: productOptionFrameMaxWidth)
//            .frame(maxHeight: .infinity)
            //                            .fixedSize(horizontal: false, vertical: true)
            //                            .frame(maxWidth: .infinity)
        }
    }
