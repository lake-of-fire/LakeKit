import SwiftUI

public protocol ActiveComponentBindable: AnyObject {
    var activeComponent: String? { get set }
    var bindingCache: [ObjectIdentifier: Binding<Bool>] { get set }
}

public extension ActiveComponentBindable {
    /// Generates a stable `Binding<Bool>` that is active only when `isActive` is `true`
    /// and `activeComponent == forComponent`.
    ///
    /// - Parameters:
    ///   - binding: The `Binding<Bool>` to be wrapped.
    ///   - forComponent: The component name controlling visibility.
    /// - Returns: A stable `Binding<Bool>`, cached for reuse.
    func binding(for binding: Binding<Bool>, forComponent component: String) -> Binding<Bool> {
        let key = ObjectIdentifier(binding as AnyObject) // Unique identifier for this binding
        
        if let cachedBinding = bindingCache[key] {
            return cachedBinding
        }
        
        let newBinding = Binding(
            get: { [weak self] in
                guard let self = self else { return false }
                return self.activeComponent == component && binding.wrappedValue
            },
            set: { _ in }
        )
        
        bindingCache[key] = newBinding
        return newBinding
    }
}
