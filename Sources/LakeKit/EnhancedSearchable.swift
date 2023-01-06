import SwiftUI
import DSFSearchField

public struct EnhancedSearchableModifier: ViewModifier {
    let autosaveName: String
    let searchAction: ((String) -> Void)
    
    @State private var temporarySearchText = ""
    @State private var searchTask: Task<Void, Never>?

    public func body(content: Content) -> some View {
#if os(macOS)
        VStack {
            DSFSearchField.SwiftUI(text: $temporarySearchText, autosaveName: autosaveName)
                .padding(.horizontal, 5)
                .onChange(of: temporarySearchText) { temporarySearchText in
                    onSearchTextChange(searchText: temporarySearchText)
                }
            content
        }
#else
        content
            .searchable(text: $temporarySearchText, placement: .automatic)
            .onChange(of: temporarySearchText) { temporarySearchText in
                onSearchTextChange(searchText: temporarySearchText)
            }
#endif
    }
    
    private func onSearchTextChange(searchText: String) {
        searchTask?.cancel()
        searchTask = Task.detached {
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
                try Task.checkCancellation()
                searchAction(searchText)
            } catch { }
        }
    }
}

public extension View {
    func enhancedSearchable(autosaveName: String, searchAction: @escaping ((String) -> Void)) -> some View {
        self.modifier(EnhancedSearchableModifier(autosaveName: autosaveName, searchAction: searchAction))
    }
}
