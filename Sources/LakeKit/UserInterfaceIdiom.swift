// From: https://github.com/SwiftUIX/SwiftUIX/blob/6a26707abd44c7ca4d58f7d9e946684a88a72124/Sources/SwiftUIX/Intramodular/Screen/UserInterfaceIdiom.swift#L8
//
// Copyright (c) Vatsal Manot
//

import Swift
import SwiftUI

fileprivate protocol _opaque_View {
    func _opaque_environmentObject<B: ObservableObject>(_: B) -> _opaque_View
    func _opaque_getViewName() -> AnyHashable?
    
    func eraseToAnyView() -> AnyView
}

// MARK: - Implementation

fileprivate extension _opaque_View where Self: View {
//    @inlinable
    func _opaque_environmentObject<B: ObservableObject>(_ bindable: B) -> _opaque_View {
        PassthroughView(content: environmentObject(bindable))
    }
    
//    @inlinable
    func _opaque_getViewName() -> AnyHashable? {
        nil
    }
    
//    @inlinable
    func eraseToAnyView() -> AnyView {
        .init(self)
    }
}

extension ModifiedContent: _opaque_View where Content: View, Modifier: ViewModifier {
    
}
fileprivate struct PassthroughView<Content: View>: _opaque_View, View {
    public let content: Content
    
    @_optimize(speed)
    @inlinable
    public init(content: Content) {
        self.content = content
    }
    
    @_optimize(speed)
    @inlinable
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    @_optimize(speed)
    @inlinable
    public var body: some View {
        content
    }
}

fileprivate extension View {
    /// Hides this view conditionally.
    @_disfavoredOverload
//    @inlinable
    func hidden(_ isHidden: Bool) -> some View {
        PassthroughView {
            if isHidden {
                hidden()
            } else {
                self
            }
        }
    }
}

fileprivate struct EnvironmentValueAccessView<Value, Content: View>: View {
    private let keyPath: KeyPath<EnvironmentValues, Value>
    private let content: (Value) -> Content
    
    @usableFromInline
    @Environment var environmentValue: Value
    
    public init(
        _ keyPath: KeyPath<EnvironmentValues, Value>,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.keyPath = keyPath
        self.content = content
        
        self._environmentValue = .init(keyPath)
    }
    
    public var body: some View {
        content(environmentValue)
    }
}

extension View {
//    @inlinable
    func environment(
        _ newEnvironment: EnvironmentValues
    ) -> some View {
        transformEnvironment(\.self) { environment in
            environment = newEnvironment
        }
    }
}

fileprivate func withEnvironmentValue<T, Content: View>(
    _ keyPath: KeyPath<EnvironmentValues, T>,
    @ViewBuilder content: @escaping (T) -> Content
) -> EnvironmentValueAccessView<T, Content> {
    .init(keyPath, content: content)
}

fileprivate class DefaultEnvironmentKey<Value>: EnvironmentKey {
    public static var defaultValue: Value? {
        nil
    }
}

public enum UserInterfaceIdiom: Hashable {
    case carPlay
    case mac
    case phone
    case pad
    case vision
    case tv
    case watch
    
    case unspecified
    
    public static var current: UserInterfaceIdiom {
#if targetEnvironment(macCatalyst)
        return .mac
#elseif os(iOS) || os(tvOS) || os(visionOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .carPlay:
            return .carPlay
        case .phone:
            return .phone
        case .pad:
            return .pad
#if swift(>=5.9)
        case .vision:
            return .vision
#endif
        case .tv:
            return .tv
        case .mac:
            return .mac
        case .unspecified:
            return .unspecified
            
        @unknown default:
            return .unspecified
        }
#elseif os(macOS)
        return .mac
#elseif os(watchOS)
        return .watch
#endif
    }
    
    public var _isMacCatalyst: Bool {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }
}

// MARK: - API

// MARK: - Auxiliary

extension EnvironmentValues {
    public var userInterfaceIdiom: UserInterfaceIdiom {
        get {
            self[DefaultEnvironmentKey<UserInterfaceIdiom>.self] ?? .current
        } set {
            self[DefaultEnvironmentKey<UserInterfaceIdiom>.self] = newValue
        }
    }
}
