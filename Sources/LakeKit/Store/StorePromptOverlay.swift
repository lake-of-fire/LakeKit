import SwiftUI
import StoreHelper
import SwiftUtilities

public extension View {
    func storePromptOverlay(isPresented: Binding<Bool>, isStoreSheetPresented: Binding<Bool>, headlineText: String, bodyText: String, storeButtonText: String, alternativeButtonText: String? = nil, alternativeButtonAction: (() -> Void)? = nil, toDismissFirst: Binding<Bool>? = nil) -> some View {
        self.modifier(StorePromptOverlayModifier(isPresented: isPresented, isStoreSheetPresented: isStoreSheetPresented, headlineText: headlineText, bodyText: bodyText, storeButtonText: storeButtonText, alternativeButtonText: alternativeButtonText, alternativeButtonAction: alternativeButtonAction, toDismissFirst: toDismissFirst))
    }
}

public struct StorePrompt: View {
    @Binding public var isPresented: Bool
    public let headlineText: String
    public let bodyText: String
    public let storeButtonText: String
    public let alternativeButtonText: String?
    public let alternativeButtonAction: (() -> Void)?
    @Binding public var toDismissFirst: Bool
    
    @ScaledMetric(relativeTo: .body) private var maxWidth = 340
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 12) {
                VStack(alignment: .center, spacing: 5) {
                    Text("Preview".uppercased())
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                    Text(headlineText)
                        .font(.headline)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(9001)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Button {
                    if !toDismissFirst {
                        isPresented = true
                    } else {
                        toDismissFirst = false
                        Task.detached {
                            do {
                                try await Task.sleep(nanoseconds: UInt64(round(0.1 * 1_000_000_000)))
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
                    .tint(.primary)
                }
                
                Text(bodyText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: maxWidth)
            .padding(8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .circular)
                .stroke(Color.gray.opacity(0.8), lineWidth: 1)
        )
    }
}

public struct StorePromptOverlayModifier: ViewModifier {
    @Binding public var isPresented: Bool
    @Binding public var isStoreSheetPresented: Bool
    public let headlineText: String
    public let bodyText: String
    public let storeButtonText: String
    public let alternativeButtonText: String?
    public let alternativeButtonAction: (() -> Void)?
    public let toDismissFirst: Binding<Bool>?
    public let presentsStoreSheet: Bool = true
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.showAds) private var showAds
    @EnvironmentObject private var storeHelper: StoreHelper
 
    private var isOverlayPresented: Bool {
        return showAds() && isPresented
    }
    
    public func body(content: Content) -> some View {
        content
            .overlay {
                if isOverlayPresented {
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: .clear, location: .zero),
                            Gradient.Stop(color: .clear, location: 0.1),
                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.5), location: 0.6),
//                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.9), location: 0.7),
                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.44), location: 1.0),
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
                if isOverlayPresented {
                    StorePrompt(isPresented: $isStoreSheetPresented, headlineText: headlineText, bodyText: bodyText, storeButtonText: storeButtonText, alternativeButtonText: alternativeButtonText, alternativeButtonAction: alternativeButtonAction, toDismissFirst: toDismissFirst ?? .constant(false))
                        .groupBoxShadow(cornerRadius: 12)
                        .padding([.leading, .trailing], 20)
                }
            }
            .scrollDisabledIfAvailable(isOverlayPresented)
    }
}
