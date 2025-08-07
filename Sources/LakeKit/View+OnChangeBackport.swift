import SwiftUI

// From: https://github.com/Max-Leopold/swiftui-toasts/blob/bc1224753c894b3d50fcced57632a2372d924852/Sources/Toast/Internals/Backports.swift
extension View {
    @ViewBuilder
    public func onChangeBackport<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, initial: initial, action)
        } else {
            self
                .onAppear {
                    if initial { action(value, value) }
                }
                .onChange(of: value) { [oldValue = value] newValue in
                    action(oldValue, newValue)
                }
        }
    }
}
