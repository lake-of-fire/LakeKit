import SwiftUI
import BetterSafariView
import SwiftUIWebView

fileprivate struct SafariViewModifier: ViewModifier {
    @Binding public var isPresented: Bool
    let url: URL
    var onDismiss: (() -> Void)?
    let entersReaderIfAvailable: Bool
    
    @ScaledMetric(relativeTo: .body) private var idealWidth: CGFloat = 650
    @ScaledMetric(relativeTo: .body) private var idealHeight: CGFloat = 500
    
    @State private var webNavigator = WebViewNavigator()
    @State private var webState = WebViewState.empty
    
    func body(content: Content) -> some View {
#if os(iOS)
        return content
            .safariView(isPresented: $isPresented) {
                SafariView(
                    url: url,
                    configuration: SafariView.Configuration(
                        entersReaderIfAvailable: entersReaderIfAvailable,
                        barCollapsingEnabled: true)
                )
                .preferredBarAccentColor(.clear)
                .preferredControlAccentColor(.accentColor)
                .dismissButtonStyle(.done)
            }
#else
        return content
            .sheet(isPresented: $isPresented) {
                VStack {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        DismissButton {
                            isPresented = false
                        }
                        .padding(.top, 1)
                        .padding(.trailing, 0)
                    }
                    WebView(
                        config: WebViewConfig(userScripts: []),
                        navigator: webNavigator,
                        state: $webState,
                        bounces: false)
//                    .fixedSize(horizontal: false, vertical: false)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        webNavigator.load(URLRequest(url: url))
                    }
                }
                .frame(idealWidth: idealWidth, idealHeight: idealHeight)
            }
#endif
    }
}

public extension View {
    func safariView(
        url: URL,
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        entersReaderIfAvailable: Bool = false
    ) -> some View {
        return self.modifier(SafariViewModifier(isPresented: isPresented, url: url, onDismiss: onDismiss, entersReaderIfAvailable: entersReaderIfAvailable))
    }
    
//    func safariView<Item: Identifiable>(
//        item: Binding<Item?>,
//        onDismiss: (() -> Void)? = nil,
//        content representationBuilder: @escaping (Item) -> SafariView
//    ) -> some View {
//        self.modifier(
//            ItemSafariViewPresentationModifier(
//                item: item,
//                onDismiss: onDismiss,
//                representationBuilder: representationBuilder
//            )
//        )
//    }
}
