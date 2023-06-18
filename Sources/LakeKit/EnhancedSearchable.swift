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
    @Binding var searchText: String
    let autosaveName: String
    let prompt: String?
    let placement: SearchFieldPlacement
    var prefersToolbarPlacement = true
    let searchAction: ((String) -> Void)
    
    @State private var isEnhancedlySearching = false
    
    private var promptText: Text? {
        guard let prompt = prompt else { return nil }
        return Text(prompt)
    }
    
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focusedField: String?

    struct InnerContentModifier: ViewModifier {
        @Binding var isEnhancedlySearching: Bool
#if os(iOS)
        @Environment(\.isSearching) private var isSearching
#endif
        
        func body(content: Content) -> some View {
            content
                .task {
                    Task { @MainActor in
                        self.isEnhancedlySearching = isSearching
                    }
                }
                .onAppear {
                    Task { @MainActor in
                        self.isEnhancedlySearching = isSearching
                    }
                }
                .onChange(of: isSearching) { isSearching in
                    Task { @MainActor in
                        self.isEnhancedlySearching = isSearching
                    }
                }
        }
    }
    
    public func body(content: Content) -> some View {
#if os(macOS)
        VStack {
            DSFSearchField.SwiftUI(text: $searchText, placeholderText: prompt, autosaveName: autosaveName, onSearchTermChange: { searchTerm in
                onSearchTextChange(searchText: searchTerm)
                Task { @MainActor in
                    isEnhancedlySearching = !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            })
            .padding(.horizontal, 5)
            .frame(maxWidth: 850)
            content
                .environment(\.isEnhancedlySearching, isEnhancedlySearching)
        }
#else
        Group {
            if prefersToolbarPlacement {
                content
                    .modifier(InnerContentModifier(isEnhancedlySearching: $isEnhancedlySearching))
                    .searchable(text: $searchText, placement: placement, prompt: promptText)
            } else {
                VStack {
                    HStack(spacing: 5) {
                        TextField(prompt ?? "Search", text: $searchText, prompt: promptText)
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
                                searchText = ""
#warning("no focus here")
                            } label: {
                                Text("Done")
                                    .bold()
                                    .padding(.horizontal, 5)
                                    .fixedSize()
                            }
                        }
                    }
//                    .fitToReadableContentWidth()
                    .padding(.horizontal, 10)
                    .frame(maxWidth: 850)
                    content
                        .environment(\.isEnhancedlySearching, isEnhancedlySearching)
                }
            }
        }
        .onChange(of: searchText) { searchText in
            onSearchTextChange(searchText: searchText)
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
    func enhancedSearchable(searchText: Binding<String>, autosaveName: String, prompt: String? = nil, placement: SearchFieldPlacement = .automatic, prefersToolbarPlacement: Bool = true, searchAction: @escaping ((String) -> Void)) -> some View {
        self.modifier(EnhancedSearchableModifier(searchText: searchText, autosaveName: autosaveName, prompt: prompt, placement: placement, prefersToolbarPlacement: prefersToolbarPlacement, searchAction: searchAction))
    }
}
