import SwiftUI
import StoreKit

public struct RestorePurchasesButton: View {
    @EnvironmentObject private var storeViewModel: StoreViewModel
    
    public init() { }
    
    public var body: some View {
        Button("Restore Purchases") {
            storeViewModel.isRestoringPurchases = true
            Task { @MainActor in
                defer { storeViewModel.isRestoringPurchases = false }
                try? await AppStore.sync()
            }
        }
        .disabled(storeViewModel.isRestoringPurchases)
    }
}
