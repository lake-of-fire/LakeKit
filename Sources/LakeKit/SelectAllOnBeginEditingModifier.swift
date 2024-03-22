//import SwiftUI
//#if os(iOS)
//import UIKit
//#elseif os(macOS)
//import AppKit
//#endif
//
//@_spi(Advanced) import SwiftUIIntrospect
//
//class TextFieldDelegate: NSObject, NSTextFieldDelegate {
//    func controlTextDidBeginEditing(_ obj: Notification) {
//        guard let textField = obj.object as? NSTextField else { return }
//        DispatchQueue.main.async {
//            textField.currentEditor()?.selectAll(nil)
//        }
//    }
//}
//
//struct SelectAllOnBeginEditingModifier: ViewModifier {
//    private static let delegate = TextFieldDelegate()
//    
//    func body(content: Content) -> some View {
//        content
//#if os(iOS)
//            .introspect(.textField, on: .iOS(.v15...)) { textField in
//                textField.addTarget(Self.delegate, action: #selector(TextFieldDelegate.controlTextDidBeginEditing(_:)), for: .editingDidBegin)
//            }
//#elseif os(macOS)
//            .introspect(.textField, on: .macOS(.v12...)) { textField in
//                textField.delegate = Self.delegate
//            }
//#endif
//    }
//}
//
//extension View {
//    func selectAllOnBeginEditing() -> some View {
//        self.modifier(SelectAllOnBeginEditingModifier())
//    }
//}
