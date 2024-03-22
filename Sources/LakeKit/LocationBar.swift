import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

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
    @Binding var selectAll: Bool
    private let onSubmit: ((URL?, String) async throws -> Void)
    @EnvironmentObject private var locationController: LocationController
    @Environment(\.colorScheme) private var colorScheme

    var url: URL? {
        get {
            guard let url = URL(string: locationText) else { return nil }
            guard url.scheme != nil && (url.host != nil || url.scheme == "about" || url.scheme == "internal") else { return nil }
            return url
        }
        set {
            locationText = newValue?.absoluteString ?? ""
        }
    }
    
    public var body: some View {
        HStack{
            TextField("", text: $locationText, prompt: Text("Search or enter website address")
                .accessibilityLabel("Location")
                .foregroundColor(.secondary))
#if os(iOS)
            .introspect(.textField, on: .iOS(.v15...)) { textField in
                if selectAll {
                    Task { @MainActor in
                        selectAll = false
                        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
                        textField.selectAll(nil)
                    }
                }
            }
#endif
            .truncationMode(.tail)
            .submitLabel((url == nil && !locationText.isEmpty) ? .search : .go)
#if os(macOS)
            .textFieldStyle(.roundedBorder)
#else
            .textContentType(.URL)
//            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.plain)
            .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
//            .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            .background(colorScheme == .dark ? Color.secondary.opacity(0.2232) : Color.white) //(white: 239.0 / 255.0))
//            .textFieldStyle(.roundedBorder)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.1), lineWidth: 1)
            )
            .submitLabel(.go)
#endif
            .onSubmit {
                Task {
                    try await onSubmit(url, locationText)
                }
            }
//            .selectAllOnBeginEditing()
#if os(macOS)
            .introspect(.textField, on: .macOS(.v12...)) { textField in
                // See: https://developer.apple.com/forums/thread/74372
                if locationController.isPresentingLocationOpening {
                    if textField.currentEditor() == nil {
                        textField.becomeFirstResponder()
                    } else {
                        locationController.isPresentingLocationOpening = false
                        textField.resignFirstResponder()
                    }
                }
            }
#else
            .introspect(.textField, on: .iOS(.v15...)) { textField in
                if locationController.isPresentingLocationOpening {
                    Task { @MainActor in
                        // See: https://developer.apple.com/forums/thread/74372
                        if textField.isFirstResponder {
                            locationController.isPresentingLocationOpening = false
                            textField.resignFirstResponder()
                        } else {
                            textField.becomeFirstResponder()
                        }
                    }
                }
            }
#endif
#if os(iOS)
            // See: https://stackoverflow.com/a/67502495/89373
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                Task { @MainActor in
                    if let textField = obj.object as? UITextField {
                        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                    }
                }
            }
#endif
            .onChange(of: action) { action in
                refreshAction(action: action)
            }
            .task {
                refreshAction()
            }
        }
    }
    
    public init(action: Binding<LocationBarAction>, locationText: Binding<String>, selectAll: Binding<Bool>, onSubmit: @escaping ((URL?, String) async throws -> Void)) {
        _action = action
        _locationText = locationText
        _selectAll = selectAll
        self.onSubmit = onSubmit
    }
    
    public static func == (lhs: LocationBar, rhs: LocationBar) -> Bool {
        return lhs.locationText == rhs.locationText && lhs.action == rhs.action
    }
    
    private func refreshAction(action: LocationBarAction? = nil) {
        let action = action ?? self.action
        Task { @MainActor in
            switch action {
            case .update(let newLocationTexts):
                if newLocationTexts == "about:blank" {
                    locationText = ""
                } else {
                    locationText = newLocationTexts
                }
                self.action = .idle
            case .idle:
                break
            }
        }
    }
}
