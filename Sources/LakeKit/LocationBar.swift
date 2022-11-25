import SwiftUI
import Introspect

public class LocationController: ObservableObject {
    @Published public var isPresentingLocationOpening = false
    
    public init() { }
}

private struct LocationTextFieldModifier: ViewModifier {
    var text: String
    
    func body(content: Content) -> some View {
        content
        // Clear color for the TextField
            .foregroundColor(.clear)
        // Overlay with text and extra
            .overlay(
                HStack(spacing: 0.0) {
                    // This Swift View splits the text and adds what I need
                    //                    TextFieldHighlightedVariables(text)
                    //                    Text
                    Text("    uh    :)")
                    Spacer()
                }
                    .padding(.top, 2)
                    .padding(.leading, 4)
                ,
                alignment: .topLeading
            )
    }
}

public struct LocationBar: View, Equatable {
//    let loadLocation: String?
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
        return TextField("Search or enter website address", text: $locationText)
            .truncationMode(.tail)
            .textFieldStyle(.roundedBorder)
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
//            .onChange(of: loadLocation) { newLocation in
//                guard let loadLocation = loadLocation else { return }
//                locationText = loadLocation
//                onSubmit(url, locationText)
//            }
            .onChange(of: locationController.isPresentingLocationOpening) { isPresentingLocationOpening in
            }
        //                .focused($isFocused)
        //                .padding(EdgeInsets(top: 0, leading: , bottom: 0, trailing: 6))
        //                .cornerRadius(5)
        //                .overlay(
        //                    RoundedRectangle(cornerRadius: 5)
        //                        .stroke(lineWidth: 1.0)
        //                )
        //                .opacity(isFocused ? 1 : 0.5)
        //        }
        //                .frame(width: min(1, geo.size.width - 90))
        //                    .frame(maxWidth: .infinity)
        //                    .fixedSize(horizontal: true, vertical: false)
    }
    
    public init(loadLocation: String?, onSubmit: @escaping ((URL?, String) -> Void)) {
        _locationText = State(initialValue: loadLocation ?? "")
        self.onSubmit = onSubmit
    }
    
    public static func == (lhs: LocationBar, rhs: LocationBar) -> Bool {
        return  lhs.locationText == rhs.locationText
    }
}
