import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
#else
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
    @Binding var locationText: String
    @Binding var selectAll: Bool
    private let onSubmit: ((URL?, String) async throws -> Void)
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
    
    @MainActor
    @ViewBuilder private var textField: some View {
        RoundedTextField(
            text: $locationText,
            placeholder: "Search or enter website address",
            selectAll: $selectAll
        )
        .onSubmit {
            Task { @MainActor in
                do {
                    try await onSubmit(url, locationText)
                } catch {
                    print(error)
                }
            }
        }
        .modifier(LocationBarIntrospection())
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
    }
    
    public var body: some View {
        HStack{
            textField
        }
    }
    
    public init(locationText: Binding<String>, selectAll: Binding<Bool>, onSubmit: @escaping ((URL?, String) async throws -> Void)) {
        _locationText = locationText
        _selectAll = selectAll
        self.onSubmit = onSubmit
    }
    
    public static func == (lhs: LocationBar, rhs: LocationBar) -> Bool {
        return lhs.locationText == rhs.locationText
    }
}
