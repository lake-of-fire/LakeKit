import SwiftUI
import StoreHelper
import StoreKit
import CloudKit
import CloudKitSyncMonitor

fileprivate struct BuyButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
///           .font(.buttonLabel)
//            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
//            .foregroundColor(.primaryButtonLabel)
            .background(configuration.isPressed ? Color.accentColor : Color.white.opacity(0.0000001))
//            .cornerRadius(.infinity)
    }
}

public struct PurchaseOptionView: View {
    public let product: Product
    @Binding public var purchaseState: PurchaseState
    public let unitsRemaining: Int?
    public let unitsPurchased: Int?
    public let unitsName: String?
    public let symbolName: String
    public let buyTitle: String
    public let action: (() -> Void)
    
    @ScaledMetric(relativeTo: .caption) private var subtitleHeight = 50
    
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
    
    public var body: some View {
        let priceViewModel = PriceViewModel(storeHelper: storeHelper, purchaseState: $purchaseState)

        GroupBox {
            Button {
                submitAction()
            } label: {
                VStack {
                    HStack(spacing: 20) {
                        Image(systemName: symbolName)
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .fixedSize()
                            .padding(12)
                            .background {
                                Circle()
                                    .foregroundColor(.accentColor)
                            }
                            .scaleEffect(1.2)
                        VStack {
                            Text(displayPrice)
                                .font(.headline)
                                .bold()
                            Text(displayPriceType)
                                .foregroundColor(.primary)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 20)
                    Group {
                        Text(product.displayName)
                            .font(.headline)
                            .padding(.horizontal)
                            .foregroundColor(.primary)
                        VStack {
                            Text(product.description)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: subtitleHeight)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    switch (purchaseState, product.type) {
                    case (.unknown, .autoRenewable):
                        ProgressView()
                            .padding()
                    case (.purchased, .autoRenewable):
                        Text("Purchased")
                            .bold()
                            .italic()
                            .foregroundColor(.primary)
                            .padding()
                    default:
                        VStack {
#if os(iOS)
                            Text(buyTitle)
                                .font(.callout)
                                .bold()
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .fixedSize(horizontal: false, vertical: true)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.accentColor, lineWidth: 1)
                                )
                                .padding()
#else
                            Button {
                                submitAction()
                            } label: {
                                Text(buyTitle)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canMakePayments)
                            .padding(.bottom, unitsLabel.isEmpty ? 4 : 0)
#endif
                            Text(unitsLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(minHeight: 24)
                            .padding(.bottom, unitsLabel.isEmpty ? 4 : 6)
                        }
                    }
                }
            }
//            .clipShape(RoundedRectangle(cornerRadius: 12))
            .buttonStyle(BuyButtonStyle())
//            .buttonBorderShape(.roundedRectangle)
//            .border(Color.accentColor, width: 2)

        }
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
            canMakePayments = AppStore.canMakePayments
            
            let isPurchased = (try? await storeHelper.isPurchased(product: product)) ?? false
            purchaseState = isPurchased ? .purchased : .notPurchased
           
            if purchaseState != .purchased {
                prePurchaseSubInfo = await priceViewModel.getPrePurchaseSubscriptionInfo(productId: product.id)
            }
        }
        .onChange(of: storeHelper.purchasedProducts) { _ in
            Task.init {
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
    
    public init(product: Product, purchaseState: Binding<PurchaseState>, unitsRemaining: Int? = nil, unitsPurchased: Int? = nil, unitsName: String? = nil, symbolName: String, buyTitle: String, action: @escaping (() -> Void)) {
        self.product = product
        self._purchaseState = purchaseState
        self.unitsRemaining = unitsRemaining
        self.unitsPurchased = unitsPurchased
        self.unitsName = unitsName
        self.symbolName = symbolName
        self.buyTitle = buyTitle
        self.action = action
    }
    
    func submitAction() {
        isPresentingICloudIssue = (product.type == .consumable) && !isICloudSyncActive && iCloudSyncStateSummary != .notStarted && iCloudSyncStateSummary != .succeeded
        if (product.type == .autoRenewable) || isICloudSyncActive {
            action()
        }
    }
}
