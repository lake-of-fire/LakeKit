import SwiftUI
import DSFSearchField
import SwiftUILayoutGuides

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
    var prefersToolbarPlacement = true
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
    @FocusState private var focusedField: String?

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
        Group {
            if prefersToolbarPlacement {
                content
                    .searchable(text: $temporarySearchText, placement: placement, prompt: promptText)
            } else {
                VStack {
                    HStack(spacing: 5) {
                        TextField(prompt ?? "Search", text: $temporarySearchText, prompt: promptText)
                            .textFieldStyle(.roundedBorder)
                        //                    DSFSearchField.SwiftUI(text: $temporarySearchText, placeholderText: prompt, autosaveName: autosaveName, onSearchTermChange: { searchTerm in
                        //                        onSearchTextChange(searchText: searchTerm)
                        //                        Task { @MainActor in
                        //                            isEnhancedlySearching = !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        //                        }
                        //                    })
                        //                    .padding(.horizontal, 5)
                        if isEnhancedlySearching {
                                Button {
                                    withAnimation {
                                        isEnhancedlySearching = false
                                        focusedField = nil
                                    }
                                    temporarySearchText = ""
#warning("no focus here")
                                } label: {
                                    Text("Done")
                                        .bold()
                                        .padding(.horizontal, 5)
                                        .fixedSize()
                                }
                        }
                    }
                    .fitToReadableContentWidth()
                    content
                        .environment(\.isEnhancedlySearching, isEnhancedlySearching)
                }
            }
        }
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
        Task { @MainActor in
            isEnhancedlySearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        searchTask?.cancel()
        searchTask = Task.detached {
            do {
                try Task.checkCancellation()
                searchAction(searchText)
            } catch { }
        }
    }
}

public extension View {
    func enhancedSearchable(autosaveName: String, prompt: String? = nil, placement: SearchFieldPlacement = .automatic, prefersToolbarPlacement: Bool = true, searchAction: @escaping ((String) -> Void)) -> some View {
        self.modifier(EnhancedSearchableModifier(autosaveName: autosaveName, prompt: prompt, placement: placement, prefersToolbarPlacement: prefersToolbarPlacement, searchAction: searchAction))
    }
}
