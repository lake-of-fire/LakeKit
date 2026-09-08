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

    let accessibilityIdentifier: String?
    
    func body(content: Content) -> some View {
        content
#if os(macOS)
            .introspect(.textField, on: .macOS(.v12...)) { textField in
                if let accessibilityIdentifier {
                    textField.setAccessibilityIdentifier(accessibilityIdentifier)
                }
                // See: https://developer.apple.com/forums/thread/74372
                if locationController.isPresentingLocationOpening {
                    // Focusing can rerun introspection. Consume the open request
                    // first so it can never become a focus toggle.
                    locationController.isPresentingLocationOpening = false
                    if textField.currentEditor() == nil {
                        textField.becomeFirstResponder()
                    }
                }
            }
#elseif os(iOS)
            .introspect(.textField, on: .iOS(.v15...)) { textField in
                if let accessibilityIdentifier {
                    textField.accessibilityIdentifier = accessibilityIdentifier
                }
                // See: https://developer.apple.com/forums/thread/74372
                if locationController.isPresentingLocationOpening {
                    Task { @MainActor in
                        guard locationController.isPresentingLocationOpening else {
                            return
                        }
                        // Focusing can rerun introspection. Consume the open request
                        // first so it can never become a focus toggle.
                        locationController.isPresentingLocationOpening = false
                        if !textField.isFirstResponder {
                            textField.becomeFirstResponder()
                        }
                    }
                }
            }
#endif
    }
}

public struct LocationBar: View {
    let prompt: String
    @Binding var locationText: String
    @Binding var selection: Any? // TextSelection
    private let accessibilityIdentifier: String?
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
        .modifier(
            LocationBarIntrospection(
                accessibilityIdentifier: accessibilityIdentifier
            )
        )
#elseif os(iOS)
        .modifier(
            LocationBarIntrospection(
                accessibilityIdentifier: accessibilityIdentifier
            )
        )
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
        accessibilityIdentifier: String? = nil,
        onSubmit: @escaping ((URL?, String) async throws -> Void)
    ) {
        _locationText = locationText
        self.prompt = prompt
        _selection = selection
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onSubmit = onSubmit
    }
}

public struct LocationBarProgressBar: View {
    public let progress: Double?
    public var tint: Color
    public var height: CGFloat
    public var hideDelay: TimeInterval

    @State private var displayProgress: Double = 0
    @State private var isVisible = false
    @State private var hideTask: Task<Void, Never>?

    public init(
        progress: Double?,
        tint: Color = .accentColor,
        height: CGFloat = 2,
        hideDelay: TimeInterval = 0.35
    ) {
        self.progress = progress
        self.tint = tint
        self.height = height
        self.hideDelay = hideDelay
    }

    public var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(tint)
                .frame(width: proxy.size.width * displayProgress, height: height)
                .opacity(isVisible ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            updateProgress(progress)
        }
        .onChange(of: progress) { newValue in
            updateProgress(newValue)
        }
    }

    @MainActor
    private func updateProgress(_ progress: Double?) {
        hideTask?.cancel()
        hideTask = nil

        let clampedProgress = max(0, min(progress ?? 0, 1))
        if let progress {
            isVisible = true
            withAnimation(.easeOut(duration: 0.12)) {
                displayProgress = clampedProgress
            }
        } else if isVisible {
            withAnimation(.easeOut(duration: 0.12)) {
                displayProgress = 1
            }
            hideTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(hideDelay * 1_000_000_000))
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = false
                }
                displayProgress = 0
            }
        } else {
            displayProgress = 0
        }
    }
}
