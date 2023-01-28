import SwiftUI
import CloudKitSyncMonitor
import CloudKit
import BigSyncKit

//struct ICloudRequiredModifier: ViewModifier {
//    @Binding var isPresented: Bool
//
//    func body(content: Content) -> some View {
//        content
//            .alert("", isPresented: <#T##Binding<Bool>#>, actions: <#T##() -> View#>)
//}
//
//public extension View {
//    func iCloudRequiredErrorAlert(isPresented: Binding<Bool>) -> some View {
//        return self.modifier(ICloudRequiredModifier(isPresented: isPresented))
//    }
//}

private struct ICloudSyncActiveEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
private struct ICloudSyncStateSummaryEnvironmentKey: EnvironmentKey {
    static let defaultValue: SyncMonitor.SyncSummaryStatus = .unknown
}
private struct ICloudSyncErrorEnvironmentKey: EnvironmentKey {
    static let defaultValue: Error? = nil
}

public extension EnvironmentValues {
    var isICloudSyncActive: Bool {
        get { self[ICloudSyncActiveEnvironmentKey.self] }
        set { self[ICloudSyncActiveEnvironmentKey.self] = newValue }
    }
    var iCloudSyncStateSummary: SyncMonitor.SyncSummaryStatus {
        get { self[ICloudSyncStateSummaryEnvironmentKey.self] }
        set { self[ICloudSyncStateSummaryEnvironmentKey.self] = newValue }
    }
    var iCloudSyncError: Error? {
        get { self[ICloudSyncErrorEnvironmentKey.self] }
        set { self[ICloudSyncErrorEnvironmentKey.self] = newValue }
    }
}

extension SyncMonitor.SyncState: Equatable {
    public static func == (lhs: CloudKitSyncMonitor.SyncMonitor.SyncState, rhs: CloudKitSyncMonitor.SyncMonitor.SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case (.inProgress(let lhsStarted), .inProgress(let rhsStarted)):
            return lhsStarted == rhsStarted
        case (.succeeded(let lhsStarted, let lhsEnded), .succeeded(let rhsStarted, let rhsEnded)):
            return lhsStarted == rhsStarted && lhsEnded == rhsEnded
        case (.failed(let lhsStarted, let lhsEnded, let lhsError), .failed(let rhsStarted, let rhsEnded, let rhsError)):
            return lhsStarted == rhsStarted && lhsEnded == rhsEnded && lhsError?.localizedDescription == rhsError?.localizedDescription
        default:
            return false
        }
    }
}

public struct ICloudStatusReaderModifier: ViewModifier {
    let cloudKitSynchronizers: [CloudKitSynchronizer]
    
    @ObservedObject private var syncMonitor: SyncMonitor = .shared
    @State private var iCloudSyncStateSummary: SyncMonitor.SyncSummaryStatus = .unknown
    @State private var iCloudSyncError: Error? = nil
    
    @State private var isAccessingZones: Bool? = nil
    @State private var zonesError: Error?
    
    @State private var isICloudSyncActive = false
    
    public func body(content: Content) -> some View {
        content
            .onChange(of: syncMonitor.setupState) { _ in
                updateStatus()
            }
            .onChange(of: syncMonitor.importState) { _ in
                updateStatus()
            }
            .onChange(of: syncMonitor.exportState) { _ in
                updateStatus()
            }
            .task {
                updateStatus()
            }
            .onAppear {
                updateStatus()
            }
            .environment(\.iCloudSyncStateSummary, iCloudSyncStateSummary)
            .environment(\.isICloudSyncActive, isICloudSyncActive)
    }
    
    public init(cloudKitSynchronizers: [CloudKitSynchronizer]) {
        self.cloudKitSynchronizers = cloudKitSynchronizers
    }
    
    private func updateStatus() {
        Task {
            await updateZonesAccessibility()
            Task { @MainActor in
                iCloudSyncStateSummary = syncMonitor.syncStateSummary
                iCloudSyncError = syncMonitor.setupError ?? syncMonitor.importError ?? syncMonitor.exportError ?? zonesError
                
                // See: https://github.com/ggruen/CloudKitSyncMonitor/issues/8
                if syncMonitor.syncStateSummary == .error, syncMonitor.iCloudAccountStatus == .available, case let .failed(_, _, error) = syncMonitor.setupState, error != nil, let zonesError = zonesError {
                    iCloudSyncError = zonesError
                }
                
                isICloudSyncActive = iCloudSyncStateSummary == .succeeded && iCloudSyncError == nil && (isAccessingZones ?? false)
            }
        }
    }
    
    private func updateZonesAccessibility() async {
        for db in cloudKitSynchronizers.compactMap({ $0.database as? DefaultCloudKitDatabaseAdapter }) {
            do {
                try await db.database.allRecordZones()
                isAccessingZones = true
                zonesError = nil
            } catch {
                isAccessingZones = false
                zonesError = error
            }
        }
    }
}

public extension View {
    func iCloudSyncStateReader(cloudKitSynchronizers: [CloudKitSynchronizer]) -> some View {
        return self.modifier(ICloudStatusReaderModifier(cloudKitSynchronizers: cloudKitSynchronizers))
    }
}
