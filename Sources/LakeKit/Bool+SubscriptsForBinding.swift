import SwiftUI

// See: https://chris.eidhof.nl/post/swiftui-binding-tricks/ and https://www.pointfree.co/clips/992082116
public extension Bool {
    subscript(negated negated: Bool) -> Bool {
        get {
            return negated ? !self : self
        }
        set {
            self = !newValue
        }
    }
    
    subscript(and value: Bool) -> Bool {
        get {
            return self && value
        }
        set { }
    }
}
