import Foundation
import SwiftUI
import AsyncView

public struct AsyncView<Success, Content: View>: View {
    @StateObject private var model: AsyncModel<Success>
    //@Binding private var showInitialContent: Bool
    private var showInitialContent: Bool
    private let content: (_ item: Success?) -> Content
    
    public var body: some View {
        switch (model.result, showInitialContent) {
//        case (.empty, true, false), (.inProgress, true, false):
        case (.empty, true), (.inProgress, true):
            content(nil)
        default:
            EmptyView()
        }
        AsyncModelView(model: self.model, content: self.content)
    }
}

public extension AsyncView {
    //init(operation: @escaping AsyncModel<Success>.AsyncOperation, showInitialContent: Binding<Bool>, @ViewBuilder content: @escaping (_ item: Success?) -> Content) {
    init(operation: @escaping AsyncModel<Success>.AsyncOperation, showInitialContent: Bool, @ViewBuilder content: @escaping (_ item: Success?) -> Content) {
        self.init(model: AsyncModel(asyncOperation: operation), showInitialContent: showInitialContent, content: content)
    }
}
