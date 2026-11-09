import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect
#if os(iOS)
import UIKit
#endif

private func logLookupKeyboardRoundedTextField(
    _ stage: String,
    placeholder: String,
    result: String
) {
    debugPrint(
        "# LOOKUPKEYBOARD",
        [
            "stage": stage,
            "placeholder": placeholder,
            "result": result
        ] as [String: Any]
    )
}

#if os(iOS)
private func lookupKeyboardResponderDescription(_ responder: UIResponder?) -> String {
    guard let responder else { return "nil" }
    if let view = responder as? UIView {
        return "\(type(of: view))@\(ObjectIdentifier(view))"
    }
    if let viewController = responder as? UIViewController {
        return "\(type(of: viewController))@\(ObjectIdentifier(viewController))"
    }
    return String(describing: type(of: responder))
}

private extension UIView {
    func lookupKeyboardFindFirstResponder() -> UIResponder? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let responder = subview.lookupKeyboardFindFirstResponder() {
                return responder
            }
        }
        return nil
    }
}
#endif

/// A reusable, rounded text field view that supports a placeholder, customizable submit button label, and an async submit action.
/// Optionally, you can pass a binding for “select all” behavior.
public struct RoundedTextField: View {
    @Binding public var text: String
    public var placeholder: String
    public var selectAll: Binding<Bool>?
    public var leftSystemImage: String?
    public var focusRequestID: Int
    public var onEditingChanged: ((Bool) -> Void)?
    
    @State private var isIconPressed: Bool = false
#if os(iOS)
    @State private var introspectedTextField: UITextField?
    @State private var shouldBecomeFirstResponder = false
#endif
    
    @Environment(\.colorScheme) private var colorScheme
    
    /// Initializes a new RoundedTextField.
    /// - Parameters:
    ///   - text: A binding to the text content.
    ///   - placeholder: The placeholder text to display.
    ///   - leftSystemImage: Optional SF Symbol name to display on the left side of the text field.
    ///   - selectAll: Optional binding that, if true, selects all text when the field appears.
    public init(text: Binding<String>,
                placeholder: String,
                leftSystemImage: String? = nil,
                selectAll: Binding<Bool>? = nil,
                focusRequestID: Int = 0,
                onEditingChanged: ((Bool) -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.selectAll = selectAll
        self.leftSystemImage = leftSystemImage
        self.focusRequestID = focusRequestID
        self.onEditingChanged = onEditingChanged
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            if let leftSystemImage {
                Image(systemName: leftSystemImage)
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.1)) {
                            isIconPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.1)) {
                                isIconPressed = false
#if os(iOS)
                                if let introspectedTextField {
                                    logLookupKeyboardRoundedTextField(
                                        "roundedTextField.becomeFirstResponder",
                                        placeholder: placeholder,
                                        result: "reason=iconTap.direct"
                                    )
                                    introspectedTextField.becomeFirstResponder()
                                } else {
                                    logLookupKeyboardRoundedTextField(
                                        "roundedTextField.becomeFirstResponder",
                                        placeholder: placeholder,
                                        result: "reason=iconTap.deferred"
                                    )
                                    shouldBecomeFirstResponder = true
                                }
#endif
                            }
                        }
                    }
            }
            
#if os(iOS)
            TextField("", text: $text, prompt: Text(placeholder) .accessibilityLabel(placeholder) .foregroundColor(.secondary))
                .introspect(.textField, on: .iOS(.v16...)) { textField in
                    if introspectedTextField !== textField {
                        Task { @MainActor in
                            guard introspectedTextField !== textField else { return }
                            introspectedTextField = textField
                            if shouldBecomeFirstResponder {
                                shouldBecomeFirstResponder = false
                                logLookupKeyboardRoundedTextField(
                                    "roundedTextField.becomeFirstResponder",
                                    placeholder: placeholder,
                                    result: "reason=deferredFocusRequest"
                                )
                                textField.becomeFirstResponder()
                            }
                        }
                    }
                    if let selectAll = selectAll, selectAll.wrappedValue {
                        Task { @MainActor in
                            selectAll.wrappedValue = false
                            try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
                            textField.selectAll(nil)
                        }
                    }
                }
                .truncationMode(.tail)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
#elseif os(macOS)
            TextField("", text: $text, prompt: Text(placeholder) .accessibilityLabel(placeholder) .foregroundColor(.secondary))
                .textFieldStyle(.roundedBorder)
#endif
        }
#if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { notification in
            guard let textField = introspectedTextField, notification.object as? UITextField === textField else { return }
            onEditingChanged?(true)
            let firstResponder = textField.window?.lookupKeyboardFindFirstResponder()
            logLookupKeyboardRoundedTextField(
                "roundedTextField.textDidBeginEditing",
                placeholder: placeholder,
                result: "textLength=\(text.count); textFieldID=\(ObjectIdentifier(textField)); windowFirstResponder=\(lookupKeyboardResponderDescription(firstResponder))"
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { notification in
            guard let textField = introspectedTextField, notification.object as? UITextField === textField else { return }
            onEditingChanged?(false)
            let firstResponder = textField.window?.lookupKeyboardFindFirstResponder()
            logLookupKeyboardRoundedTextField(
                "roundedTextField.textDidEndEditing",
                placeholder: placeholder,
                result: "textLength=\(text.count); textFieldID=\(ObjectIdentifier(textField)); windowFirstResponder=\(lookupKeyboardResponderDescription(firstResponder))"
            )
        }
        .onChange(of: focusRequestID) { _ in
            if let introspectedTextField {
                logLookupKeyboardRoundedTextField(
                    "roundedTextField.becomeFirstResponder",
                    placeholder: placeholder,
                    result: "reason=focusRequestID.direct"
                )
                introspectedTextField.becomeFirstResponder()
            } else {
                logLookupKeyboardRoundedTextField(
                    "roundedTextField.becomeFirstResponder",
                    placeholder: placeholder,
                    result: "reason=focusRequestID.deferred"
                )
                shouldBecomeFirstResponder = true
            }
        }
#endif
#if os(iOS)
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .background(
            (colorScheme == .dark ? Color.secondary.opacity(0.2232) : Color.white)
                .opacity(isIconPressed ? 0.8 : 1.0)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
#endif
    }
}
