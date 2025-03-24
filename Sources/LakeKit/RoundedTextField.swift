import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect
#if os(iOS)
import UIKit
#endif

/// A reusable, rounded text field view that supports a placeholder, customizable submit button label, and an async submit action.
/// Optionally, you can pass a binding for “select all” behavior.
public struct RoundedTextField: View {
    @Binding public var text: String
    public var placeholder: String
    public var selectAll: Binding<Bool>?
    public var leftSystemImage: String?
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var isIconPressed: Bool = false
    
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
                selectAll: Binding<Bool>? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.selectAll = selectAll
        self.leftSystemImage = leftSystemImage
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
                                isTextFieldFocused = true
                            }
                        }
                    }
            }
            
            TextField("", text: $text, prompt: Text(placeholder) .accessibilityLabel(placeholder) .foregroundColor(.secondary))
                .focused($isTextFieldFocused)
#if os(iOS)
                .introspect(.textField, on: .iOS(.v16...)) { textField in
                    if let selectAll = selectAll, selectAll.wrappedValue {
                        Task { @MainActor in
                            selectAll.wrappedValue = false
                            // Slight delay to ensure the text field is ready before selecting all.
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
                .textFieldStyle(.roundedBorder)
#endif
        }
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
