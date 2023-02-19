import SwiftUI
import DSFSearchField

struct IsEnhancedlySearchingKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var isEnhancedlySearching: Bool {
        get { self[IsEnhancedlySearchingKey.self] }
        set { self[IsEnhancedlySearchingKey.self] = newValue }
    }
}

public struct EnhancedSearchableModifier: ViewModifier {
    let autosaveName: String
    let prompt: String?
    let placement: SearchFieldPlacement
    let searchAction: ((String) -> Void)
    
    @State private var isEnhancedlySearching = false
#if os(iOS)
    @Environment(\.isSearching) private var isSearching
#endif
    
    private var promptText: Text? {
        guard let prompt = prompt else { return nil }
        return Text(prompt)
    }
    
    @State private var temporarySearchText = ""
    @State private var searchTask: Task<Void, Never>?

    public func body(content: Content) -> some View {
#if os(macOS)
        VStack {
            DSFSearchField.SwiftUI(text: $temporarySearchText, placeholderText: prompt, autosaveName: autosaveName, onSearchTermChange: { searchTerm in
                onSearchTextChange(searchText: searchTerm)
                Task { @MainActor in
                    isEnhancedlySearching = !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            })
                .padding(.horizontal, 5)
            content
                .environment(\.isEnhancedlySearching, isEnhancedlySearching)
        }
#else
        content
            .searchable(text: $temporarySearchText, placement: placement, prompt: promptText)
            .onChange(of: temporarySearchText) { temporarySearchText in
                onSearchTextChange(searchText: temporarySearchText)
            }
            .onChange(of: isSearching) { isSearching in
                self.isEnhancedlySearching = isSearching
            }
            .environment(\.isEnhancedlySearching, isEnhancedlySearching)
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
    func enhancedSearchable(autosaveName: String, prompt: String? = nil, placement: SearchFieldPlacement = .automatic, searchAction: @escaping ((String) -> Void)) -> some View {
        self.modifier(EnhancedSearchableModifier(autosaveName: autosaveName, prompt: prompt, placement: placement, searchAction: searchAction))
    }
}
