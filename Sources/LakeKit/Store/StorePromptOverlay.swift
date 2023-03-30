import SwiftUI

public extension View {
    func storePromptOverlay(storeViewModel: StoreViewModel, headlineText: String, bodyText: String, storeButtonText: String, alternativeButtonText: String? = nil, alternativeButtonAction: (() -> Void)? = nil) -> some View {
        self.modifier(StorePromptOverlayModifier(storeViewModel: storeViewModel, headlineText: headlineText, bodyText: bodyText, storeButtonText: storeButtonText, alternativeButtonText: alternativeButtonText, alternativeButtonAction: alternativeButtonAction))
    }
}

public struct StorePromptOverlayModifier: ViewModifier {
    @ObservedObject public var storeViewModel: StoreViewModel
    public let headlineText: String
    public let bodyText: String
    public let storeButtonText: String
    public let alternativeButtonText: String?
    public let alternativeButtonAction: (() -> Void)?
    
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
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: .clear, location: .zero),
                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.9), location: 0.3),
                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.9), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 150)
                    GroupBox {
                        VStack(alignment: .center, spacing: 15) {
                            Text("Preview".uppercased())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(headlineText)
                                .font(.headline)
                                .bold()
                            Text(bodyText)
                                .font(.callout)
                            Button(storeButtonText) {
                                storeViewModel.isPresentingStoreSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            if let alternativeButtonText = alternativeButtonText, let alternativeButtonAction = alternativeButtonAction {
                                Button(alternativeButtonText, action: alternativeButtonAction)
                                    .buttonStyle(.bordered)
                            }
                        }
                        .multilineTextAlignment(.center)
                    }
                    .padding()
                    .padding()
                }
                
//                Color(uiColor: .systemBackground)
//                    .mask(alignment: .top) {
//                        VStack(spacing: 0) {
//                            LinearGradient(
//                                stops: [
//                                    Gradient.Stop(color: .clear, location: .zero),
//                                    Gradient.Stop(color: .black, location: 1.0)
//                                ],
//                                startPoint: .top,
//                                endPoint: .bottom
//                            )
//                            .frame(height: 32)
//                            Color.black
//                        }
//                    }
//                    .padding(.top, -32)
//                    .ignoresSafeArea(.all, edges: .bottom)
            }
    }
}
