import SwiftUI

// From: https://stackoverflow.com/questions/69712759/swiftui-fullscreencover-with-no-animation
public func withoutAnimation(action: @escaping () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
        action()
    }
}
