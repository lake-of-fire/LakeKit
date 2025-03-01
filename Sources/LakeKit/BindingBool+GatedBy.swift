import SwiftUI

/// Warning: This can cause sheets to change identity rapidly upon presentation
public extension Binding where Value == Bool {
    func gatedBy(_ gate: Binding<Bool>) -> Binding<Bool> {
        return Binding<Bool>(
            get: { wrappedValue && gate.wrappedValue },
            set: { newValue in
                wrappedValue = newValue
            })
    }
}


@available(*, deprecated, message: "Use gatedBy")
public extension Binding where Value == Bool {
    static func &&(_ lhs: Binding<Bool>, _ rhs: Bool) -> Binding<Bool> {
        return Binding<Bool>( get: { lhs.wrappedValue && rhs },
                              set: { newValue in lhs.wrappedValue = newValue })
    }
}
