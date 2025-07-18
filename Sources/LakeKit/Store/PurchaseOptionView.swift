import SwiftUI
import StoreHelper
import StoreKit
import CloudKit
import CloudKitSyncMonitor
import SwiftUtilities

public struct PurchaseOptionView: View {
    public let storeViewModel: StoreViewModel
    public let storeProductVersions: StoreProductVersions
    @Binding public var purchaseState: PurchaseState
    public let maxWidth: CGFloat
    public let action: ((StoreProduct, Product) -> Void)
    
    @AppStorage("pendingReferralCode") private var pendingReferralCode: String?
    
    @EnvironmentObject private var storeHelper: StoreHelper
    
    private var hasValidReferralCode: Bool {
        return !(pendingReferralCode?.isEmpty ?? true)
    }
    
    var storeProduct: StoreProduct {
        if hasValidReferralCode {
            return storeProductVersions.referralProduct
        } else {
            return storeProductVersions.product
        }
    }
    
    public var body: some View {
        if let product = storeProduct.product(storeHelper: storeHelper) {
            PurchaseOptionVersionView(
                storeViewModel: storeViewModel,
                product: product,
                storeProduct: storeProduct,
                purchaseState: $purchaseState,
                unitsRemaining: storeProduct.unitsRemaining,
                unitsPurchased: storeProduct.unitsPurchased,
                unitsName: storeProduct.unitsName,
                symbolName: storeProduct.iconSymbolName,
                buyTitle: storeProduct.buyButtonTitle,
                maxWidth: maxWidth,
                action: action
            )
        }
    }
}

fileprivate struct PurchaseOptionVersionView: View {
    public let storeViewModel: StoreViewModel
    public let product: Product
    public let storeProduct: StoreProduct
    @Binding public var purchaseState: PurchaseState
    public let unitsRemaining: Int?
    public let unitsPurchased: Int?
    public let unitsName: String?
    public let symbolName: String
    public let buyTitle: String?
    public let maxWidth: CGFloat
    public let action: ((StoreProduct, Product) -> Void)
    
    @AppStorage("pendingReferralCode") private var pendingReferralCode: String?
    
    //    @ScaledMetric(relativeTo: .caption) private var subtitleWidth = 50
    //    @ScaledMetric(relativeTo: .caption) private var subtitleHeight = 40
    @ScaledMetric(relativeTo: .body) private var buttonIdealWidth = 145
    @ScaledMetric(relativeTo: .body) private var buttonHorizontalPadding = 24
    #if os(iOS)
    @ScaledMetric(relativeTo: .caption2) private var popularBadgeHeight: CGFloat = 20
    #elseif os(macOS)
    @ScaledMetric(relativeTo: .caption2) private var popularBadgeHeight: CGFloat = 18
    #endif

    @Environment(\.isICloudSyncActive) private var isICloudSyncActive: Bool
    @Environment(\.iCloudSyncStateSummary) private var iCloudSyncStateSummary: SyncMonitor.SyncSummaryStatus
    @Environment(\.iCloudSyncError) private var iCloudSyncError: Error?
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPresentingICloudIssue = false
    
    @EnvironmentObject private var storeHelper: StoreHelper
    @State private var prePurchaseSubInfo: PrePurchaseSubscriptionInfo?
    @State private var canMakePayments: Bool = false
    @State private var offerSubtitle: String?

    init(
        storeViewModel: StoreViewModel,
        product: Product,
        storeProduct: StoreProduct,
        purchaseState: Binding<PurchaseState>,
        unitsRemaining: Int? = nil,
        unitsPurchased: Int? = nil,
        unitsName: String? = nil,
        symbolName: String,
        buyTitle: String?,
        maxWidth: CGFloat,
        action: @escaping ((StoreProduct, Product) -> Void)
    ) {
        self.storeViewModel = storeViewModel
        self.product = product
        self.storeProduct = storeProduct
        self._purchaseState = purchaseState
        self.unitsRemaining = unitsRemaining
        self.unitsPurchased = unitsPurchased
        self.unitsName = unitsName
        self.symbolName = symbolName
        self.buyTitle = buyTitle
        self.maxWidth = maxWidth
        self.action = action
    }
    
    /// The eligible introductory or promotional offer for this product, if any.
    private var availableOffer: SubscriptionOfferInfo? {
        guard product.type == .autoRenewable, let info = prePurchaseSubInfo else { return nil }
        // Promotional offers take precedence.
        if info.promotionalOffersEligible, let promo = info.promotionalOffers.first {
            return promo
        }
        // Fall back to an introductory offer if the user is eligible.
        if info.introductoryOfferEligible, let intro = info.introductoryOffer {
            return intro
        }
        return nil
    }
    
    /// `true` when the current offer represents an actual price discount
    /// (i.e. it is *not* just a free‑trial period).
    private var hasDiscountedPrice: Bool {
        guard let mode = availableOffer?.paymentMode else { return false }
        return mode != .freeTrial
    }
    
    /// Price string shown most prominently (discounted price if applicable).
    private var displayPrice: String {
        if hasDiscountedPrice, let offerPrice = availableOffer?.offerPrice {
            return offerPrice
        }
        return product.displayPrice
    }
    
    private var displayPriceType: String {
        if product.type == .autoRenewable {
            // TODO: Support promos if needed
            guard let renewalPeriod = prePurchaseSubInfo?.subscriptionPeriod else { return "" }
            var renewalString = "per "
            if renewalPeriod.value > 1 {
                renewalString += renewalPeriod.value.formatted() + " "
            }
            if #available(iOS 16, macOS 13, *) {
                renewalString += renewalPeriod.unit.formatted(product.subscriptionPeriodUnitFormatStyle)
            } else {
                switch renewalPeriod.unit {
                case .day: renewalString += "day"
                case .week: renewalString += "week"
                case .month: renewalString += "month"
                case .year: renewalString += "year"
                }
                if renewalPeriod.value > 1 {
                    renewalString += "s"
                }
            }
            return renewalString
        }
        return "one time"
    }
    
    private var displayICloudMessage: String {
        var result = iCloudSyncStateSummary.description
        if let error = iCloudSyncError {
            if let ckError = error as? CKError {
                result += "\n\n\(ckError.localizedDescription) (Error Code \(ckError.errorCode))"
            } else {
                result += "\n\n\(error.localizedDescription)"
            }
        }
        return result
    }
    
    private var unitsLabel: String {
        if product.type == .consumable, let unitsRemaining = unitsRemaining, let unitsPurchased = unitsPurchased, let unitsName = unitsName {
            return "\(unitsRemaining) remaining of \(unitsPurchased) \(unitsName) purchased."
        }
        return ""
    }
    
    private var isUnitsLabelVisible: Bool {
        return storeViewModel.products.contains(where: { !$0.product.isSubscription || !$0.referralProduct.isSubscription })
    }
    
    var body: some View {
        Button {
            submitAction()
        } label: {
            GroupBox {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Circle()
                            .modifier {
                                if #available(iOS 16, macOS 13, *) {
//                                    $0.fill(Color.accentColor.gradient)
                                    $0.strokeBorder(Color.accentColor.gradient, lineWidth: 2)
                                } else {
//                                    $0.foregroundColor(Color.accentColor)
                                    $0.strokeBorder(Color.accentColor, lineWidth: 2)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: symbolName)
                                    .font(.system(size: 17))
//                                    .foregroundColor(.white)
                                    .modifier {
                                        if #available(iOS 16, macOS 13, *) {
                                            $0
                                                .foregroundStyle(Color.accentColor.gradient)
                                                .fontWeight(.semibold)
                                        } else {
                                            $0.foregroundColor(Color.accentColor)
                                        }
                                    }
                                    .fixedSize()
                            }
                            .clipShape(Circle())
                            .fixedSize()
                        Spacer()
                            .frame(minWidth: 5, idealWidth: 15)
                        VStack(spacing: 0) {
                            // Original price with strikethrough when a discounted offer exists
                            if hasDiscountedPrice {
                                Text(product.displayPrice)
                                    .font(.caption2)
                                    .strikethrough()
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // Main (possibly discounted) price
                            Text(displayPrice)
                                .font(.headline)
                                .bold()
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Renewal / one‑time descriptor
                            Text(displayPriceType)
                                .multilineTextAlignment(.center)
//                                .foregroundColor(.secondary)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                    
                    if let subtitle = offerSubtitle {
                        Text(subtitle)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    
                    if buyTitle != nil {
                        Text(product.displayName)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(9001)
                            .padding(.horizontal, 5)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    //                        Text(product.description)
                    //                            .font(.caption)
                    //                            .multilineTextAlignment(.center)
                    //                            .lineLimit(9001)
                    //                            .foregroundColor(.secondary)
                    //                            .fixedSize(horizontal: false, vertical: true)
                    //                            .padding(.vertical, 12)
                    
                    if product.type == .autoRenewable, [PurchaseState.purchased, .pending, .inProgress].contains(purchaseState) {
                        if purchaseState == .inProgress {
                            ProgressView()
                            //                                    .padding()
                        } else {
                            Text(purchaseState.shortDescription())
                                .bold()
                                .italic()
                                .foregroundColor(.primary)
                                .padding()
                        }
                    } else {
                        VStack {
                            Group {
#if os(iOS)
                                //                            Text(buyTitle ?? product.displayName)
                                Text("Unlock")
                                //                                .font(.callout)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, buttonHorizontalPadding)
                                    .padding(.vertical, 5)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .background(
                                        Capsule()
                                            .foregroundColor(Color.accentColor)
                                    )
                                    .conditionalEffect(
                                        .repeat(
                                            .shine.delay(0.75),
                                            every: 4
                                        ),
                                        condition: true
                                    )
#else
                                Button {
                                    submitAction()
                                } label: {
                                    //                                Text(buyTitle ?? product.displayName)
                                    Text("Unlock")
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!canMakePayments)
                                .padding(.bottom, unitsLabel.isEmpty ? 4 : 0)
#endif
                            }
                            .padding(.top, 10)

                            if isUnitsLabelVisible {
                                Text(unitsLabel)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(minHeight: 24)
                                    .padding(.bottom, unitsLabel.isEmpty ? 4 : 6)
                            }
                        }
                    }
                }
#if os(macOS)
                .padding(6)
#endif
            }
            .frame(idealWidth: buttonIdealWidth)
            .fixedSize()
            .overlay(alignment: .top) {
                if let badgeText = storeProduct.badgeText {
                    ZStack {
                        Text(badgeText)
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .textCase(.uppercase)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .padding(.horizontal, 10)
                            .frame(minHeight: popularBadgeHeight)
                    }
                    .background(
                        Capsule()
                            .modifier {
                                if #available(iOS 16, macOS 13, *) {
                                    $0.fill(Color.green.gradient)
                                } else {
                                    $0.foregroundColor(Color.green)
                                }
                            }
                    )
                    .offset(y: -popularBadgeHeight / 2)
                }
            }
            .padding(.top, popularBadgeHeight / 2) // So badge doesn’t get clipped
#if os(iOS)
            .modifier {
                if #available(iOS 16, macOS 13, *), colorScheme == .light {
                    $0.backgroundStyle(Color.systemBackground)
                } else { $0 }
            }
#endif
        }
        .buttonStyle(.plain)
        //            .backgroundStyle(.secondary)
        //            .foregroundStyle(.primary)
        //            .frame(idealWidth: buttonIdealWidth)
        //        }
        //        .frame(maxWidth: maxWidth)
        //        .buttonBorderShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        //        .buttonStyle(.borderless)
        .disabled(!canMakePayments || purchaseState == .purchased || purchaseState == .unknown)
        //        .overlay(
        //            RoundedRectangle(cornerRadius: 12)
        //                .inset(by: 5) // inset value should be same as lineWidth in .stroke
        //                .stroke(Color.accentColor, lineWidth: 2)
        //        )
        //        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        //        .clipped()
        //        .buttonBorderShape(.roundedRectangle)
        //        .border(Color.accentColor, width: 2)
        .task(id: storeProduct.id) { @MainActor in
            canMakePayments = AppStore.canMakePayments
            
            let isPurchased = (try? await storeHelper.isPurchased(product: product)) ?? false
            purchaseState = isPurchased ? .purchased : .notPurchased
            
            if purchaseState != .purchased {
                let priceViewModel = PriceViewModel(storeHelper: storeHelper, purchaseState: $purchaseState)
                prePurchaseSubInfo = await priceViewModel.getPrePurchaseSubscriptionInfo(productId: product.id)
                if let prePurchaseSubInfo {
                    offerSubtitle = createOfferDisplay(
                        product: product,
                        prePurchaseSubInfo: prePurchaseSubInfo
                    )
                } else {
                    
                }
            }
        }
        .onChange(of: storeHelper.purchasedProducts) { _ in
            Task { @MainActor in
                let isPurchased = (try? await storeHelper.isPurchased(product: product)) ?? false
                purchaseState = isPurchased ? .purchased : .notPurchased
            }
        }
        .alert("iCloud Sign-in Required for Pay As You Go", isPresented: $isPresentingICloudIssue, actions: {
            Button("I'll Verify iCloud Sign-in") { }
            Button("I'll Wait for iCloud Sync") { }
        }, message: {
            if iCloudSyncStateSummary == .notStarted {
                Text("You may be signed into iCloud, but iCloud synchronization has not started yet. Please verify that you are signed into iCloud, otherwise your Pay As You Go tokens purchase may be lost in the event of a device issue without a backup.\n\nIf you do not want to use iCloud, you may instead purchase a subscription which does not require iCloud.")
            } else {
                Text("Please sign into iCloud, or try a Monthly Savings subscription to get tokens without needing iCloud.\n\n(iCloud issue description: \(iCloudSyncStateSummary.description). \(displayICloudMessage))")
            }
        })
    }
    
    private func createOfferDisplay(
        product: Product,
        prePurchaseSubInfo: PrePurchaseSubscriptionInfo
    ) -> String? {
        guard let offer = availableOffer, let sub = product.subscription else {
            return nil
        }
        if prePurchaseSubInfo.promotionalOffersEligible, !prePurchaseSubInfo.promotionalOffers.isEmpty, let promoOffer = sub.promotionalOffers.first {
            return createOfferDisplay(
                for: promoOffer.paymentMode,
                product: product,
                price: promoOffer.displayPrice,
                period: promoOffer.period,
                periodCount: promoOffer.periodCount,
                offerType: promoOffer.type
            )
        } else if prePurchaseSubInfo.introductoryOfferEligible, let introOffer = product.subscription?.introductoryOffer {
            return createOfferDisplay(
                for: introOffer.paymentMode,
                product: product,
                price: introOffer.displayPrice,
                period: introOffer.period,
                periodCount: introOffer.periodCount,
                offerType: introOffer.type
            )
        }
        return nil
    }
    
    private func createOfferDisplay(
        for paymentMode: Product.SubscriptionOffer.PaymentMode,
        product: Product,
        price: String,
        period: Product.SubscriptionPeriod,
        periodCount: Int,
        offerType: Product.SubscriptionOffer.OfferType
    ) -> String? {
        guard let sub = product.subscription else { return nil }
        let offer = sub.promotionalOffers
        
        switch paymentMode {
        case .payAsYouGo:
            return "for the \(periodCount == 1 ? "first" : "first \(periodCount)") \(periodUnitText(period.unit, product: product)) and then \(product.displayPrice) per \(periodUnitText(period.unit, product: product)) after that"
        case .payUpFront:
            let result = "by paying up-front for the \(periodCount == 1 ? "first" : "first \(periodCount)") \(periodUnitText(period.unit, product: product)) and then \(product.displayPrice) per \(periodUnitText(period.unit, product: product)) after that"
            return "\(periodText(period, product: product)) at\n \(offerType == .introductory ? "an introductory" : "a promotional") price of\n \(price)"
        case .freeTrial:
            return "\(periodText(period, product: product))\n\(offerType == .introductory ? "free trial" : "promotional period at no charge")"
        default:
            return nil
        }
    }
    
    // Forked from StoreHelper
    private func periodUnitText(_ unit: Product.SubscriptionPeriod.Unit, product: Product) -> String {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *) {
            let format = product.subscriptionPeriodUnitFormatStyle.locale(.current)
            return unit.formatted(format)
        } else if #available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.6, *) {
            return unit.localizedDescription
        } else {
            switch unit {
            case .day:          return "day"
            case .week:         return "week"
            case .month:        return "month"
            case .year:         return "year"
            @unknown default:   return "unknown"
            }
        }
    }
    
    // Forked from StoreHelper
    private func periodText(_ period: Product.SubscriptionPeriod, product: Product) -> String {
        var format = product.subscriptionPeriodFormatStyle
        format.style = .wide
        format.locale = .current
        return period.formatted(format)
    }
    
    func submitAction() {
        Task.detached {
            guard await storeViewModel.satisfyingPrerequisite() else { return }
            Task { @MainActor in
                isPresentingICloudIssue = (product.type == .consumable) && !isICloudSyncActive && iCloudSyncStateSummary != .notStarted && iCloudSyncStateSummary != .succeeded
                if (product.type == .autoRenewable) || isICloudSyncActive {
                    action(storeProduct, product)
                }
            }
        }
    }
}

fileprivate extension Color {
    static var gold: Color {
        //        get { return UIColor(red: 255/255, green: 243/255, blue: 117/255, alpha: 1) }
        Color(red: 254.0/255, green: 180.0/255, blue: 0.0/255)
        //        get { return UIColor(red: 236/255, green: 180/255, blue: 71/255, alpha: 1) }
        //        get { return UIColor(red: 175/255, green: 153/255, blue: 91/255, alpha: 1) }
    }
}
