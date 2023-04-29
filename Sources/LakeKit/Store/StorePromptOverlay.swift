import SwiftUI

public extension View {
    func storePromptOverlay(storeViewModel: StoreViewModel, isStoreSheetPresented: Binding<Bool>, headlineText: String, bodyText: String, storeButtonText: String, alternativeButtonText: String? = nil, alternativeButtonAction: (() -> Void)? = nil, toDismissFirst: Binding<Bool>? = nil) -> some View {
        self.modifier(StorePromptOverlayModifier(storeViewModel: storeViewModel, isStoreSheetPresented: isStoreSheetPresented, headlineText: headlineText, bodyText: bodyText, storeButtonText: storeButtonText, alternativeButtonText: alternativeButtonText, alternativeButtonAction: alternativeButtonAction, toDismissFirst: toDismissFirst))
    }
}

public struct StorePrompt: View {
    @ObservedObject public var storeViewModel: StoreViewModel
    @Binding public var isPresented: Bool
    public let headlineText: String
    public let bodyText: String
    public let storeButtonText: String
    public let alternativeButtonText: String?
    public let alternativeButtonAction: (() -> Void)?
    @Binding public var toDismissFirst: Bool
    
    @ScaledMetric(relativeTo: .body) private var maxWidth = 300
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 15) {
                VStack(alignment: .center, spacing: 5) {
                    Text("Preview".uppercased())
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                    Text(headlineText)
                        .font(.headline)
                        .bold()
                }
                
                Button {
                    if !toDismissFirst {
                        isPresented = true
                    } else {
                        toDismissFirst = false
                        Task.detached {
                            do {
                                try await Task.sleep(nanoseconds: UInt64(round(0.05 * 1_000_000_000)))
                                Task { @MainActor in
                                    isPresented = true
                                }
                            }
                        }
                    }
                } label: {
                    Text(storeButtonText)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                if let alternativeButtonText = alternativeButtonText, let alternativeButtonAction = alternativeButtonAction {
                    Button(action: alternativeButtonAction, label: {
                        Text(alternativeButtonText)
                            .frame(maxWidth: .infinity)
                    })
                    .buttonStyle(.bordered)
                }
                
                Text(bodyText)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: maxWidth)
            .padding(8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
    
public struct StorePromptOverlayModifier: ViewModifier {
    @ObservedObject public var storeViewModel: StoreViewModel
    @Binding public var isStoreSheetPresented: Bool
    public let headlineText: String
    public let bodyText: String
    public let storeButtonText: String
    public let alternativeButtonText: String?
    public let alternativeButtonAction: (() -> Void)?
    public let toDismissFirst: Binding<Bool>?
    public let presentsStoreSheet: Bool = true
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var isPresented: Bool {
        return !storeViewModel.isSubscribed
    }
    
    public func body(content: Content) -> some View {
        content
            .modifier {
                if #available(iOS 16, macOS 13, *) {
                    $0.scrollDisabled(isPresented)
                } else { $0 }
            }
            .overlay {
                if isPresented {
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: .clear, location: .zero),
                            Gradient.Stop(color: .clear, location: 0.1),
                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.5), location: 0.5),
//                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.9), location: 0.7),
                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.2), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                    //                .padding(.top, 150)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fixedSize(horizontal: false, vertical: false)
                    .ignoresSafeArea()
                }
            }
            .overlay(alignment: .center) {
                if isPresented {
                    StorePrompt(storeViewModel: storeViewModel, isPresented: $isStoreSheetPresented, headlineText: headlineText, bodyText: bodyText, storeButtonText: storeButtonText, alternativeButtonText: alternativeButtonText, alternativeButtonAction: alternativeButtonAction, toDismissFirst: toDismissFirst ?? .constant(false))
                        .groupBoxShadow(cornerRadius: 12)
                        .padding([.leading, .trailing])
                        .padding([.leading, .trailing])
                }
            }
            .modifier {
                if presentsStoreSheet {
                    $0.storeSheet(isPresented: $isStoreSheetPresented, storeViewModel: storeViewModel)
                } else { $0 }
            }
    }
}
