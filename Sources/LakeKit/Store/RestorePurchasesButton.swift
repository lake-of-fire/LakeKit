import SwiftUI

public struct RestorePurchasesButton: View {
    @EnvironmentObject private var storeViewModel: StoreViewModel
    @State private var restoreError: String?
    
    public init() { }
    
    public var body: some View {
        Button("Restore Purchases") {
            Task { @MainActor in
                // Ignore taps queued before another restore button became disabled.
                guard !storeViewModel.isRestoringPurchases else { return }
                restoreError = await storeViewModel.restorePurchases()
            }
        }
        .disabled(storeViewModel.isRestoringPurchases)
        .alert("Unable to Restore Purchases", isPresented: Binding(
            get: { restoreError != nil },
            set: { if !$0 { restoreError = nil } }
        )) {
            Button("OK", role: .cancel) { restoreError = nil }
        } message: {
            Text(restoreError ?? "Please try again.")
        }
    }
}
