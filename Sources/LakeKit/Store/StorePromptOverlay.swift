import SwiftUI

public extension View {
    func storePromptOverlay(storeViewModel: StoreViewModel, headlineText: String, bodyText: String, storeButtonText: String, alternativeButtonText: String? = nil, alternativeButtonAction: (() -> Void)? = nil, toDismissFirst: Binding<Bool>? = nil) -> some View {
        self.modifier(StorePromptOverlayModifier(storeViewModel: storeViewModel, headlineText: headlineText, bodyText: bodyText, storeButtonText: storeButtonText, alternativeButtonText: alternativeButtonText, alternativeButtonAction: alternativeButtonAction, toDismissFirst: toDismissFirst))
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
        GroupBox {
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
                            Task {
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
                    Text(bodyText)
                        .font(.callout)
                        .foregroundColor(.secondary)
                    if let alternativeButtonText = alternativeButtonText, let alternativeButtonAction = alternativeButtonAction {
                        Button(action: alternativeButtonAction, label: {
                            Text(alternativeButtonText)
                                .frame(maxWidth: .infinity)
                        })
                        .buttonStyle(.bordered)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: maxWidth)
            }
            .fixedSize(horizontal: false, vertical: true)
            //                                    .offset(y: geometry.size.height * 0.25)
        }
    }
//
//    public init(storeViewModel: StoreViewModel, headlineText: String, bodyText: String, storeButtonText: String, alternativeButtonText: String? = nil, alternativeButtonAction: (() -> Void)? = nil) {
//        self.storeViewModel = storeViewModel
//        self.headlineText = headlineText
//        self.bodyText = bodyText
//        self.storeButtonText = storeButtonText
//        self.alternativeButtonText = alternativeButtonText
//        self.alternativeButtonAction = alternativeButtonAction
//    }
}
    
public struct StorePromptOverlayModifier: ViewModifier {
    @ObservedObject public var storeViewModel: StoreViewModel
    public let headlineText: String
    public let bodyText: String
    public let storeButtonText: String
    public let alternativeButtonText: String?
    public let alternativeButtonAction: (() -> Void)?
    public let toDismissFirst: Binding<Bool>?
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isStoreSheetPresented = false
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
                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.9), location: 0.3),
                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.9), location: 0.7),
                            Gradient.Stop(color: (colorScheme == .dark ? Color.black : .white).opacity(0.98), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    //                .padding(.top, 150)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fixedSize(horizontal: false, vertical: false)
                    .ignoresSafeArea()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isPresented {
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            Spacer()
                                .frame(height: geometry.size.height * 0.25)
                            StorePrompt(storeViewModel: storeViewModel, isPresented: $isStoreSheetPresented, headlineText: headlineText, bodyText: bodyText, storeButtonText: storeButtonText, alternativeButtonText: alternativeButtonText, alternativeButtonAction: alternativeButtonAction, toDismissFirst: toDismissFirst ?? .constant(false))
                                .groupBoxShadow()
                                .padding([.leading, .trailing])
                                .padding([.leading, .trailing, .bottom])
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .fixedSize(horizontal: false, vertical: false)
                    }
                    //                            .frame(maxWidth: .infinity)
                }
            }
    }
    
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
//            }
//    }
//}
