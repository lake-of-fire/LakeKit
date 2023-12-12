import SwiftUI
import BetterSafariView



fileprivate struct SafariViewModifier: ViewModifier {
    @Binding public var isPresented: Bool
    let url: URL
    var onDismiss: (() -> Void)?
    let entersReaderIfAvailable: Bool
    
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
