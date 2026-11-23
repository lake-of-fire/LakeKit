import Foundation
import SwiftUI

public struct RestorePurchasesButton: View {
    @EnvironmentObject private var storeViewModel: StoreViewModel
    @State private var restoreRequestID: UUID?
    @State private var restoreError: String?
    
    public init() { }
    
    public var body: some View {
        Button("Restore Purchases") { restorePurchases() }
            .disabled(storeViewModel.isRestoringPurchases || restoreRequestID != nil)
            .alert("Unable to Restore Purchases", isPresented: Binding(
                get: { restoreError != nil },
                set: { if !$0 { restoreError = nil } }
            )) {
                Button("OK", role: .cancel) { restoreError = nil }
            } message: {
                Text(restoreError ?? "Please try again.")
            }
            .onDisappear {
                restoreRequestID = nil
                restoreError = nil
            }
    }

    @MainActor
    private func restorePurchases() {
        guard restoreRequestID == nil else { return }
        let requestID = UUID()
        restoreRequestID = requestID
        guard let restore = storeViewModel.beginRestorePurchases() else {
            restoreRequestID = nil
            return
        }
        Task { @MainActor in
            let error = await restore.value
            guard restoreRequestID == requestID else { return }
            restoreRequestID = nil
            restoreError = error
        }
    }
}
