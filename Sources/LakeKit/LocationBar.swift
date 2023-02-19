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
    @Binding var locationText: String
    private let onSubmit: ((URL?, String) -> Void)
    @EnvironmentObject private var locationController: LocationController
    @Environment(\.colorScheme) private var colorScheme

    var url: URL? {
        get {
            guard let url = URL(string: locationText) else { return nil }
            guard url.scheme != nil && (url.host != nil || url.scheme == "about") else { return nil }
            return url
        }
        set {
                                    print("update loc")

            locationText = newValue?.absoluteString ?? ""
        }
    }
    
    public var body: some View {
        HStack{
            TextField("", text: $locationText, prompt: Text("Search or enter website address")
                .foregroundColor(.secondary))
            .truncationMode(.tail)
#if os(macOS)
            .textFieldStyle(.roundedBorder)
#else
            .textContentType(.URL)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .textFieldStyle(.plain)
            .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
            .background(colorScheme == .dark ? Color.secondary.opacity(0.2232) : Color(white: 239.0 / 255.0))
            .cornerRadius(8)
            .submitLabel(.go)
#endif
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
                        textField.resignFirstResponder()
                    }
#else
                    if textField.isFirstResponder {
                        locationController.isPresentingLocationOpening = false
                        textField.resignFirstResponder()
                    } else {
                        textField.becomeFirstResponder()
                    }
#endif
                }
            }
            // See: https://stackoverflow.com/a/67502495/89373
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                Task { @MainActor in
                    if let textField = obj.object as? UITextField {
                        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                    }
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
    }
    
    public init(action: Binding<LocationBarAction>, locationText: Binding<String>, onSubmit: @escaping ((URL?, String) -> Void)) {
        _action = action
        _locationText = locationText
        self.onSubmit = onSubmit
    }
    
    public static func == (lhs: LocationBar, rhs: LocationBar) -> Bool {
        return lhs.locationText == rhs.locationText && lhs.action == rhs.action
    }
}
