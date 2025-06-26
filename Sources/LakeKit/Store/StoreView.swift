import SwiftUI
import StoreHelper
import StoreKit
//import Collections
import Pow


public extension View {
    func storeSheet(isPresented: Binding<Bool>) -> some View {
        self.modifier(StoreSheetModifier(isPresented: isPresented))
    }
}

fileprivate struct StoreViewForSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var storeViewModel: StoreViewModel
    @Environment(\.dismiss) var dismiss
    
    @State var isRestoringPurchases = false
    
    var body: some View {
#if os(iOS)
        StoreView(isPresented: $isPresented, storeViewModel: storeViewModel)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore Purchases") {
                        isRestoringPurchases = true
                        Task.init { @MainActor in
                            defer { isRestoringPurchases = false }
                            try? await AppStore.sync()
                        }
                    }
                    .foregroundStyle(.secondary)
                    .disabled(isRestoringPurchases)
                    .fixedSize()
                }
                ToolbarItem(placement: .cancellationAction) {
                    DismissButton {
                        dismiss()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: storeViewModel.isSubscribed) { isSubscribed in
                if isSubscribed {
                    dismiss()
                    Task { @MainActor in
                        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            if #available(iOS 18, *) {
                                AppStore.requestReview(in: scene)
                            } else {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }
                    }
                }
            }
#elseif os(macOS)
        StoreView(isPresented: $isPresented, storeViewModel: storeViewModel)
            .padding(.top, 10)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    HStack {
                        Button("Restore Purchases") {
                            isRestoringPurchases = true
                            Task.init { @MainActor in
                                defer { isRestoringPurchases = false }
                                try? await AppStore.sync()
                            }
                        }
                        .disabled(isRestoringPurchases)
                        .fixedSize()
                        Spacer()
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                }
            }
            .frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 760)
            .onChange(of: storeViewModel.isSubscribed) { isSubscribed in
                if isSubscribed {
                    dismiss()
                }
            }
#endif
    }
}

public struct StoreSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
#if os(iOS)
                NavigationView {
                    StoreViewForSheet(isPresented: $isPresented)
                }
                .navigationViewStyle(.stack)
#else
                StoreViewForSheet(isPresented: $isPresented)
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
    @Binding var isExpanded: Bool
    let discountView: Content
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            discountView
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(Image(systemName: "info.circle"))
                    .font(.title)
                    .padding(.trailing, 5)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Subsidized pricing for affordability")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Student & Low-Income Discounts") // \(Image(systemName: "chevron.right"))")
                        .font(.headline)
                        .bold()
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundColor(.accentColor)
            .background(.secondary.opacity(0.0000000001))
        }
        .onTapGesture(count: 1) {
            withAnimation { isExpanded.toggle() }
        }
    }
    
    public init(isExpanded: Binding<Bool>, discountView contentBuilder: () -> Content) {
        _isExpanded = isExpanded
        discountView = contentBuilder()
    }
}

fileprivate struct ViewStudentDiscountButton: View {
    @Binding var isStudentDiscountExpanded: Bool
    let scrollValue: ScrollViewProxy
    
    var body: some View {
        Button {
            scrollValue.scrollTo("education-discount", anchor: .top)
            isStudentDiscountExpanded = true
        } label: {
            (Text("Student & low-income discounts") + Text("  \(Image(systemName: "chevron.right.circle.fill"))"))
            //                .font(.callout)
                .bold()
                .lineLimit(9001)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            //                .padding(5)
        }
        //        .buttonStyle(.bordered)
        .buttonStyle(.borderless)
#if os(iOS)
        .modifier {
            if #available(iOS 15, macOS 14, *) {
                $0.buttonBorderShape(.capsule)
            } else { $0 }
        }
#endif
    }
}

fileprivate struct AddReferralCodeButton: View {
    @AppStorage("pendingReferralCode") private var pendingReferralCode: String?
    @EnvironmentObject private var storeViewModel: StoreViewModel
    
    @State private var referralCodeInput: String = ""
    @State private var showingReferralAlert: Bool = false
    @State private var referralStatusMessage: String?
    @State private var referralCodeToValidate: String?
    
    var body: some View {
        VStack {
            Button {
                showingReferralAlert = true
            } label: {
                (Text("Have a referral code?") + Text("  \(Image(systemName: "chevron.right.circle"))"))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .alert("Enter Referral Code", isPresented: $showingReferralAlert) {
                TextField("Referral Code", text: $referralCodeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                Button("OK") {
                    referralCodeToValidate = referralCodeInput.lowercased()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter your referral code to apply it to your purchase.")
            }
            .onChange(of: referralCodeToValidate) { newValue in
                guard let code = newValue?.lowercased(), !code.isEmpty else {
                    referralStatusMessage = nil
                    pendingReferralCode = nil
                    return
                }
                Task { @MainActor in
                    do {
                        let isValid = try await storeViewModel.validateReferralCode(code)
                        if isValid {
                            pendingReferralCode = code
                        } else {
                            pendingReferralCode = nil
                        }
                    } catch {
                        referralStatusMessage = "Failed to validate referral code: \(error.localizedDescription)"
                    }
                }
            }
            .task(id: pendingReferralCode) { @MainActor in
                refreshMessage()
            }
            
            if let message = referralStatusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(!(pendingReferralCode?.isEmpty ?? true) ? .primary : .red)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                //                    .padding(.top, 4)
            }
        }
    }
    
    @MainActor
    private func refreshMessage() {
        guard let code = pendingReferralCode, !code.isEmpty else {
            guard let referralCodeToValidate, !referralCodeToValidate.isEmpty else {
                referralStatusMessage = nil
                return
            }
            referralStatusMessage = "Referral code \"\(referralCodeToValidate.uppercased())\" invalid or expired."
            return
        }
        referralStatusMessage = "✔️ Referral code \"\(code.uppercased())\" is active!"
    }
}

fileprivate struct PrimaryTestimonialView: View {
    @ObservedObject var storeViewModel: StoreViewModel
    
    @ScaledMetric private var laurelHeight: CGFloat = 75
    @ScaledMetric private var awardImageHeight: CGFloat = 36
    enum LaurelSide {
        case left
        case right
        
        var imageSuffix: String {
            switch self {
            case .left: return "Left"
            case .right: return "Right"
            }
        }
    }
    
    @ViewBuilder
    func laurelImage(side: LaurelSide) -> some View {
        Image("Laurel \(side.imageSuffix)")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
//            .frame(height: height)
            .foregroundStyle(.secondary)
            .frame(height: laurelHeight)
    }
    
    var body: some View {
        if let awardTestimonial = storeViewModel.awardTestimonial {
            VStack(alignment: .center) {
                if let awardTitle = storeViewModel.awardTitle, let awardImage = storeViewModel.awardImage {
                    HStack(alignment: .bottom, spacing: 0) {
                        Spacer(minLength: 0)
                        laurelImage(side: .left)
                            .padding(.trailing, 5)
                        
                        VStack(alignment: .center) {
                            Text(awardTitle)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            if let awardLink = storeViewModel.awardLink {
                                Link(destination: awardLink) {
                                    awardImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: awardImageHeight)
                                }
                            } else {
                                awardImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: awardImageHeight)
                            }
                        }
                        .foregroundStyle(.primary)

                        laurelImage(side: .right)
                            .padding(.leading, 5)
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 8)
                }
                if let awardLink = storeViewModel.awardLink {
                    Link(destination: awardLink) {
                        Text("“\(awardTestimonial)”") + Text("  \(Image(systemName: "chevron.right.circle"))")
                            .italic()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                } else {
                    Text("“\(awardTestimonial)”")
                        .italic()
                        .font(.subheadline)
                }
            }
        }
    }
}

fileprivate struct QuestionsAndAnswersView: View {
    @ObservedObject var storeViewModel: StoreViewModel
    
    var body: some View {
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
    }
}

fileprivate struct StoreFooterView: View {
    @ObservedObject var storeViewModel: StoreViewModel
    
    var body: some View {
        if let chatURL = storeViewModel.chatURL {
            GroupBox {
                Text("Got a question? Need help?")
                    .font(.headline)
                Link(destination: chatURL) { Label("Chat With Team", systemImage: "message.circle") }
                    .font(.subheadline)
                    .padding(.top, 8)
            }
            .padding(.top, 8)
        }
        HStack(spacing: 20) {
            Link("Terms of Service", destination: storeViewModel.termsOfService)
            //                        .frame(maxWidth: .infinity)
            Divider()
            Link("Privacy Policy", destination: storeViewModel.privacyPolicy)
            //                        .frame(maxWidth: .infinity)
        }
        .tint(.secondary)
        .font(.footnote)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 10)
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
                Spacer(minLength: 0)
            }
            .foregroundColor(.accentColor)
            .background(.secondary.opacity(0.0000000001))
        }
        .onTapGesture(count: 1) {
            withAnimation { isExpanded.toggle() }
        }
    }
    
    public init(content contentBuilder: () -> Content) {
        content = contentBuilder()
    }
}

public struct StoreView: View {
    @Binding public var isPresented: Bool
    @ObservedObject public var storeViewModel: StoreViewModel
    
    @AppStorage("pendingReferralCode") private var pendingReferralCode: String?
    
    @ScaledMetric(relativeTo: .title2) private var storeWidth = 666
    @ScaledMetric(relativeTo: .title2) private var storeHeight = 590
    
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    
    @EnvironmentObject private var storeHelper: StoreHelper
    
    @State private var isPresentingTokenLimitError = false
    @State private var isStudentDiscountExpanded = false
    
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
    
    private func storeOptionsMaxWidth(geometrySize: CGSize) -> CGFloat {
        return max(0, geometrySize.width - 10)
    }
    
    private func componentMaxWidth(geometrySize: CGSize) -> CGFloat {
        return geometrySize.width
    }
    
    @ViewBuilder private var headlineView: some View {
        Group {
            Text(storeViewModel.headline)
                .font(.title)
                .bold()
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(storeViewModel.subheadline)
                .foregroundColor(.secondary)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, secondaryHorizontalPadding)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder private func primaryPurchasingView(geometry: GeometryProxy, scrollValue: ScrollViewProxy) -> some View {
        VStack {
            VStack {
                Text(storeViewModel.productGroupHeading)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                
                purchaseOptionsGrid(
                    storeProductVersions: storeViewModel.products,
                    maxWidth: storeOptionsMaxWidth(geometrySize: geometry.size)
                )
                .frame(maxWidth: storeOptionsMaxWidth(geometrySize: geometry.size))
                .padding(.bottom, 10)
                
                if let productGroupSubtitle = storeViewModel.productGroupSubtitle, !productGroupSubtitle.isEmpty {
                    Text(productGroupSubtitle)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if storeViewModel.awardTestimonial != nil {
                    ViewStudentDiscountButton(
                        isStudentDiscountExpanded: $isStudentDiscountExpanded,
                        scrollValue: scrollValue
                    )
                }
                AddReferralCodeButton()
                    .padding(.top, 5)
            }
            .padding(8)
        }
        .background {
#if os(iOS)
            //            Color.systemGroupedBackground.opacity(0.8)
            Rectangle()
                .modifier {
                    if #available(iOS 16, macOS 13, *) {
                        $0.fill(Color.systemGroupedBackground.opacity(0.65).gradient)
                    } else {
                        $0.fill(Color.systemGroupedBackground.opacity(0.65))
                    }
                }
#elseif os(macOS)
                .fill(Color.gray.opacity(0.15))
            //            Color.gray.opacity(0.15)
#endif
        }
    }
    
    @ViewBuilder private func purchaseOptionsGrid(
        storeProductVersions: [StoreProductVersions],
        maxWidth: CGFloat
    ) -> some View {
        if #available(iOS 16, macOS 13, *) {
            ViewThatFits {
                HStack(alignment: .top, spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(alignment: .top, spacing: 20) {
                        purchaseOptions(
                            storeProductVersions: storeProductVersions,
                            maxWidth: maxWidth
                        )
                    }
                    .fixedSize()
                    Spacer(minLength: 0)
                }
                HStack(alignment: .top, spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(alignment: .top, spacing: 10) {
                        purchaseOptions(
                            storeProductVersions: storeProductVersions,
                            maxWidth: maxWidth
                        )
                    }
                    .fixedSize()
                    Spacer(minLength: 0)
                }
                VStack(alignment: .center) {
                    purchaseOptions(
                        storeProductVersions: storeProductVersions,
                        maxWidth: maxWidth
                    )
                }
                .fixedSize()
            }
            .frame(maxWidth: maxWidth)
        } else {
            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .top, spacing: 10) {
                    purchaseOptions(
                        storeProductVersions: storeProductVersions,
                        maxWidth: maxWidth
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }
    
    @ViewBuilder private func purchaseOptions(
        storeProductVersions: [StoreProductVersions],
        maxWidth: CGFloat
    ) -> some View {
        ForEach(storeProductVersions) { (storeProductVersions: StoreProductVersions) in
            productOptionView(
                storeProductVersions: storeProductVersions,
                maxWidth: maxWidth
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    public var body: some View {
        // FIXME:
        GeometryReader { geometry in
            ScrollViewReader { scrollValue in
                ScrollView {
                    VStack(spacing: 10) {
                        headlineView
                        
                        primaryPurchasingView(geometry: geometry, scrollValue: scrollValue)
                        
                        Group {
                            PrimaryTestimonialView(storeViewModel: storeViewModel)
                                .padding(.horizontal, secondaryHorizontalPadding)
                            
                            GroupBox {
                                StudentDiscountDisclosureGroup(
                                    isExpanded: $isStudentDiscountExpanded,
                                    discountView: {
                                        VStack {
                                            Text("Students and those who cannot afford the full-price rates are welcome to a special discount. The low-income discount requires that you cannot afford the regular price. These discounts are subsidized by customers who pay the full price.")
                                                .font(.subheadline)
                                                .padding()
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(9001)
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            purchaseOptionsGrid(
                                                storeProductVersions: storeViewModel.studentProducts,
                                                maxWidth: storeOptionsMaxWidth(geometrySize: geometry.size)
                                            )
                                            //                                    .fixedSize(horizontal: true, vertical: false)
                                            .frame(maxWidth: storeOptionsMaxWidth(geometrySize: geometry.size))
                                            
                                            AddReferralCodeButton()
                                                .padding(.top, 16)
                                        }
                                        .padding(.top, 5)
                                    })
                            }
                            .id("education-discount")
                            
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
                            Divider()
                            VStack(alignment: .leading, spacing: 15) {
                                ForEach(storeViewModel.benefits, id: \.self) { benefit in
                                    Text(Image(systemName: "checkmark.circle.fill"))
                                        .bold()
                                        .foregroundColor(.green)
                                    + Text(" ")
                                    + Text(.init(benefit))
                                }
                            }
                            .font(.callout)
                            .padding(.top, 5)
                            .padding(.horizontal, secondaryHorizontalPadding)
                            
                            QuestionsAndAnswersView(storeViewModel: storeViewModel)
                                .padding(.top, 10)
                            
                            StoreFooterView(storeViewModel: storeViewModel)
                        }
                        .padding(.horizontal)
                        Spacer()
                    }
                    .padding(.bottom)
                }
            }
        }
        .onChange(of: storeViewModel.isSubscribed) { isSubscribed in
            Task { @MainActor in
                if isSubscribed {
                    isPresented = false
                }
            }
        }
    }
    
    //    private var productOptionFrameMaxWidth: CGFloat? {
    //#if os(iOS)
    //        if horizontalSizeClass == .compact {
    //            return nil
    //        } else { }
    //#endif
    //        return .infinity
    //    }
    
    public init(isPresented: Binding<Bool>, storeViewModel: StoreViewModel) {
        _isPresented = isPresented
        self.storeViewModel = storeViewModel
    }
    
    @ViewBuilder func productOptionView(
        storeProductVersions: StoreProductVersions,
        maxWidth: CGFloat
    ) -> some View {
        let priceViewModel = PriceViewModel(storeHelper: storeHelper, purchaseState: $storeViewModel.purchaseState)
        PurchaseOptionView(
            storeViewModel: storeViewModel,
            storeProductVersions: storeProductVersions,
            purchaseState: $storeViewModel.purchaseState,
            maxWidth: maxWidth
        ) { storeProduct, product in
            storeViewModel.purchase(
                storeProduct: storeProduct,
                storeKitProduct: product,
                priceViewModel: priceViewModel
            )
        }
        //        .frame(maxWidth: productOptionFrameMaxWidth)
        //            .frame(maxHeight: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .changeEffect(
            .shine.delay(2),
            value: isPresented,
            isEnabled: isPresented && [.notPurchased, .notStarted, .unknown].contains(storeViewModel.purchaseState)
        )
        .shadow(radius: 4)
    }
}
