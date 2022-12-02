import SwiftUI

#if os(iOS)
public struct CheckboxToggleStyle: ToggleStyle{
    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .center) {
                Image(systemName: configuration.isOn
                      ? "checkmark.circle.fill"
                      : "circle")
                .padding(.trailing, 6)
                configuration.label
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    public init() { }
}

public extension ToggleStyle where Self == CheckboxToggleStyle {
    static var iOSCheckbox: CheckboxToggleStyle {
        get { CheckboxToggleStyle() }
    }
}
#endif
