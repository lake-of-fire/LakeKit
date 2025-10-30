// From: https://github.com/SwiftUIX/SwiftUIX/blob/6a26707abd44c7ca4d58f7d9e946684a88a72124/Sources/SwiftUIX/Intramodular/Screen/UserInterfaceIdiom.swift#L8
//
// Copyright (c) Vatsal Manot
//

import SwiftUI

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
