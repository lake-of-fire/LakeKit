import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public class LocationController: ObservableObject {
    @Published public var isPresentingLocationOpening = false
    
    public init() { }
}

fileprivate struct LocationBarIntrospection: ViewModifier {
    @EnvironmentObject private var locationController: LocationController
    
    func body(content: Content) -> some View {
        content
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
#elseif os(iOS)
            .introspect(.textField, on: .iOS(.v15...)) { textField in
                // See: https://developer.apple.com/forums/thread/74372
                if locationController.isPresentingLocationOpening {
                    Task { @MainActor in
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
    }
}

public struct LocationBar: View, Equatable {
    let prompt: String
    @Binding var locationText: String
    @Binding var selection: Any? // TextSelection
    private let onSubmit: ((URL?, String) async throws -> Void)
    
    @Environment(\.colorScheme) private var colorScheme
    
    @FocusState private var isFocused: Bool
    
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
    
    @ViewBuilder
    private var textFieldPrompt: Text {
        Text(prompt)
    }
    
    @ViewBuilder private var textField: some View {
        Group {
            if #available(iOS 18, macOS 15, *) {
                TextField(
                    "",
                    text: $locationText,
                    selection: Binding<TextSelection?>(
                        get: { selection as! TextSelection? },
                        set: { selection = $0 }
                    ),
                    prompt: textFieldPrompt
                )
            } else {
                TextField(
                    "",
                    text: $locationText,
                    prompt: textFieldPrompt
                )
            }
        }
        .focused($isFocused)
        .autocorrectionDisabled()
#if os(iOS)
        .textInputAutocapitalization(.never)
        .keyboardType(.URL)
        .textContentType(.URL)
#endif
        .onSubmit {
            Task { @MainActor in
                do {
                    try await onSubmit(url, locationText)
                } catch {
                    print(error)
                }
            }
        }
#if os(macOS)
        .modifier(LocationBarIntrospection())
#endif
        .onChange(of: isFocused) { isFocused in
            if #available(iOS 18, macOS 15, *) {
                if isFocused {
                    selection = TextSelection(range: locationText.startIndex..<locationText.endIndex)
                }
            }
        }
//#if os(iOS)
//        // See: https://stackoverflow.com/a/67502495/89373
//        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
//            Task { @MainActor in
//                if let textField = obj.object as? UITextField {
//                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
//                }
//            }
//        }
//#endif
    }
    
    public var body: some View {
        textField
    }
    
    public init(
        locationText: Binding<String>,
        prompt: String,
        selection: Binding<Any?>,
        onSubmit: @escaping ((URL?, String) async throws -> Void)
    ) {
        _locationText = locationText
        self.prompt = prompt
        _selection = selection
        self.onSubmit = onSubmit
    }
    
    public static func == (lhs: LocationBar, rhs: LocationBar) -> Bool {
        return lhs.locationText == rhs.locationText && lhs.prompt == rhs.prompt
    }
}
