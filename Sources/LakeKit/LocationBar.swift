import SwiftUI
import Introspect

public class LocationController: ObservableObject {
    @Published public var isPresentingLocationOpening = false
    
    public init() { }
}

//private struct LocationTextFieldModifier: ViewModifier {
//    var text: String
//    
//    func body(content: Content) -> some View {
//        content
//        // Clear color for the TextField
//            .foregroundColor(.clear)
//        // Overlay with text and extra
//            .overlay(
//                HStack(spacing: 0.0) {
//                    // This Swift View splits the text and adds what I need
//                    //                    TextFieldHighlightedVariables(text)
//                    //                    Text
//                    Text("    uh    :)")
//                    Spacer()
//                }
//                    .padding(.top, 2)
//                    .padding(.leading, 4)
//                ,
//                alignment: .topLeading
//            )
//    }
//}

public enum LocationBarAction: Equatable {
    case idle
    case update(String)
    
    public static func == (lhs: LocationBarAction, rhs: LocationBarAction) -> Bool {
        if case .idle = lhs, case .idle = rhs {
            return true
        }
        if case .update(let lhsLocation) = lhs, case .update(let rhsLocation) = rhs {
            return lhsLocation == rhsLocation
        }
        return false
    }
}

public struct LocationBar: View, Equatable {
    @Binding var action: LocationBarAction
    @State private var locationText = ""
    private let onSubmit: ((URL?, String) -> Void)
    @EnvironmentObject private var locationController: LocationController
    
    var url: URL? {
        get {
            guard let url = URL(string: locationText) else { return nil }
            guard url.scheme != nil && (url.host != nil || url.scheme == "about") else { return nil }
            return url
        }
        set { locationText = newValue?.absoluteString ?? "" }
    }
    
    public var body: some View {
        TextField("Search or enter website address", text: $locationText)
            .truncationMode(.tail)
        #if os(macOS)
            .textFieldStyle(.roundedBorder)
        #else
            .textFieldStyle(.plain)
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 9, trailing: 10))
            .background(Color.secondary.opacity(0.2232))
            .cornerRadius(8)
        #endif
            .submitLabel(.go)
            .onSubmit {
                onSubmit(url, locationText)
            }
            .introspectTextField { textField in
                // See: https://developer.apple.com/forums/thread/74372
                if locationController.isPresentingLocationOpening {
#if os(macOS)
                    if textField.currentEditor() == nil {
                        textField.becomeFirstResponder()
                    } else {
                        locationController.isPresentingLocationOpening = false
                    }
#else
                    if textField.isFirstResponder {
                        locationController.isPresentingLocationOpening = false
                    } else {
                        textField.becomeFirstResponder()
                    }
#endif
                } else if !locationController.isPresentingLocationOpening {
                    textField.resignFirstResponder()
                }
            }
            .onChange(of: action) { action in
                DispatchQueue.main.async {
                    switch action {
                    case .update(let newLocationTexts):
                        locationText = newLocationTexts
                        self.action = .idle
                    case .idle:
                        break
                    }
                }
            }
    }
    
    public init(action: Binding<LocationBarAction>, onSubmit: @escaping ((URL?, String) -> Void)) {
        _action = action
        self.onSubmit = onSubmit
    }
    
    public static func == (lhs: LocationBar, rhs: LocationBar) -> Bool {
        return  lhs.locationText == rhs.locationText
    }
}
