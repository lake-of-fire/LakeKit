import SwiftUI

public extension Binding where Value == Bool {
    static func &&(_ lhs: Binding<Bool>, _ rhs: Bool) -> Binding<Bool> {
        return Binding<Bool>( get: { lhs.wrappedValue && rhs },
                              set: { newValue in lhs.wrappedValue = newValue })
    }
}
