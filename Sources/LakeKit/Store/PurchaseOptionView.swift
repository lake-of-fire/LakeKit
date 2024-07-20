import SwiftUI
import StoreHelper
import StoreKit
import CloudKit
import CloudKitSyncMonitor
import SwiftUtilities

fileprivate struct BuyButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
///           .font(.buttonLabel)
//            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
//            .foregroundColor(.primaryButtonLabel)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.0000001))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
//            .cornerRadius(.infinity)
    }
}

public struct PurchaseOptionView: View {
    public let storeViewModel: StoreViewModel
    public let product: Product
    @Binding public var purchaseState: PurchaseState
    public let unitsRemaining: Int?
    public let unitsPurchased: Int?
    public let unitsName: String?
    public let symbolName: String
    public let buyTitle: String?
    public let maxWidth: CGFloat
    public let action: (() -> Void)
    
//    @ScaledMetric(relativeTo: .caption) private var subtitleWidth = 50
//    @ScaledMetric(relativeTo: .caption) private var subtitleHeight = 40
    @ScaledMetric(relativeTo: .body) private var buttonIdealWidth = 145
    @ScaledMetric(relativeTo: .body) private var buttonHorizontalPadding = 12
    
    @Environment(\.isICloudSyncActive) private var isICloudSyncActive: Bool
    @Environment(\.iCloudSyncStateSummary) private var iCloudSyncStateSummary: SyncMonitor.SyncSummaryStatus
    @Environment(\.iCloudSyncError) private var iCloudSyncError: Error?
    @State private var isPresentingICloudIssue = false
    
    @EnvironmentObject private var storeHelper: StoreHelper
    @State private var prePurchaseSubInfo: PrePurchaseSubscriptionInfo?
    @State private var canMakePayments: Bool = false

    private var displayPrice: String {
        if product.type == .autoRenewable {
            // TODO: Support promos if needed
            return product.displayPrice
        } else if product.type == .consumable {
            return product.displayPrice
        }
        return "$---"
    }
    
    private var displayPriceType: String {
        if product.type == .autoRenewable {
            // TODO: Support promos if needed
            return prePurchaseSubInfo?.renewalPeriod?.replacingOccurrences(of: "/ ", with: "per ") ?? ""
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
        return storeViewModel.products.contains(where: { !$0.isSubscription })
    }
    
    public var body: some View {
            Button {
                submitAction()
            } label: {
                GroupBox {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Circle()
                                .modifier {
                                    if #available(iOS 16, macOS 13, *) {
                                        $0.fill(Color.accentColor.gradient)
                                    } else {
                                        $0.foregroundColor(Color.accentColor)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: symbolName)
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .fixedSize()
                                }
                                .clipShape(Circle())
                                .fixedSize()
                            Spacer()
                                .frame(minWidth: 5, idealWidth: 15)
                            VStack(spacing: 0) {
                                Text(displayPrice)
                                    .font(.headline)
                                    .bold()
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(displayPriceType)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                        
                        if buyTitle != nil {
                            Text(product.displayName)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .lineLimit(9001)
                                .padding(.horizontal, 5)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Text(product.description)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .lineLimit(9001)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 12)
                        
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
#if os(iOS)
                                //                            Text(buyTitle ?? product.displayName)
                                Text("Upgrade")
                                //                                .font(.callout)
                                    .bold()
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, buttonHorizontalPadding)
                                    .padding(.vertical, 6)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .background(
                                        Capsule()
                                            .foregroundColor(Color.accentColor)
                                    )
#else
                                Button {
                                    submitAction()
                                } label: {
                                    //                                Text(buyTitle ?? product.displayName)
                                    Text("Upgrade")
                                        .bold()
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!canMakePayments)
                                .padding(.bottom, unitsLabel.isEmpty ? 4 : 0)
#endif
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
                }
                .frame(idealWidth: buttonIdealWidth)
                .fixedSize()
            }
//            .buttonStyle(BuyButtonStyle())
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
        .task {
            Task { @MainActor in
                canMakePayments = AppStore.canMakePayments
                
                let isPurchased = (try? await storeHelper.isPurchased(product: product)) ?? false
                purchaseState = isPurchased ? .purchased : .notPurchased
                
                if purchaseState != .purchased {
                    let priceViewModel = PriceViewModel(storeHelper: storeHelper, purchaseState: $purchaseState)
                    prePurchaseSubInfo = await priceViewModel.getPrePurchaseSubscriptionInfo(productId: product.id)
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
    
    public init(storeViewModel: StoreViewModel, product: Product, purchaseState: Binding<PurchaseState>, unitsRemaining: Int? = nil, unitsPurchased: Int? = nil, unitsName: String? = nil, symbolName: String, buyTitle: String?, maxWidth: CGFloat, action: @escaping (() -> Void)) {
        self.storeViewModel = storeViewModel
        self.product = product
        self._purchaseState = purchaseState
        self.unitsRemaining = unitsRemaining
        self.unitsPurchased = unitsPurchased
        self.unitsName = unitsName
        self.symbolName = symbolName
        self.buyTitle = buyTitle
        self.maxWidth = maxWidth
        self.action = action
    }
    
    func submitAction() {
        Task.detached {
            guard await storeViewModel.satisfyingPrerequisite() else { return }
            Task { @MainActor in
                isPresentingICloudIssue = (product.type == .consumable) && !isICloudSyncActive && iCloudSyncStateSummary != .notStarted && iCloudSyncStateSummary != .succeeded
                if (product.type == .autoRenewable) || isICloudSyncActive {
                    action()
                }
            }
        }
    }
}
