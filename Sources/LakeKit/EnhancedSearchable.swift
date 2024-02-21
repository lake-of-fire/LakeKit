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
    @Binding var isPresented: Bool
    let canHide: Bool
    @Binding var searchText: String
    let autosaveName: String
    let prompt: String?
    let placement: SearchFieldPlacement
    var prefersToolbarPlacement = true
    let searchAction: ((String) -> Void)
    
    @State private var isEnhancedlySearching = false
#if os(iOS)
    @State private var isIOSSearching = false
#endif
    
    private var promptText: Text? {
        guard let prompt = prompt else { return nil }
        return Text(prompt)
    }
    
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focusedField: String?

    struct InnerContentModifier: ViewModifier {
        @Binding var isEnhancedlySearching: Bool
        @Binding var isIOSSearching: Bool
#if os(iOS)
        @Environment(\.isSearching) private var isSearching
#endif
        
        func body(content: Content) -> some View {
            content
#if os(iOS)
                .task { @MainActor in
                    isEnhancedlySearching = isSearching
                    isIOSSearching = isSearching
                }
                .onAppear {
                    Task { @MainActor in
                        isEnhancedlySearching = isSearching
                        isIOSSearching = isSearching
                    }
                }
                .onChange(of: isSearching) { isSearching in
                    Task { @MainActor in
                        isEnhancedlySearching = isSearching
                        isIOSSearching = isSearching
                    }
                }
#endif
        }
    }
    
    public func body(content: Content) -> some View {
        VStack {
#if os(macOS)
            if isPresented {
                HStack {
                    DSFSearchField.SwiftUI(text: $searchText, placeholderText: prompt, autosaveName: autosaveName, onSearchTermChange: { searchTerm in
                        onSearchTextChange(searchText: searchTerm)
                        //                Task { @MainActor in
                        //                    isEnhancedlySearching = !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        //                }
                    })
                    .focused($focusedField, equals: "search")
                    .onExitCommand {
                        withAnimation(.linear(duration: 0.075)) {
                            searchText = ""
                            isPresented = false
                            isEnhancedlySearching = false
                        }
                    }
                    
                    if isPresented && (canHide || isEnhancedlySearching) {
                        Button("Cancel") {
                            withAnimation(.linear(duration: 0.075)) {
                                searchText = ""
                                isPresented = false
                                isEnhancedlySearching = false
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 5)
                .frame(maxWidth: 850)
                .transition(.opacity)
            }
            content
                .environment(\.isEnhancedlySearching, isEnhancedlySearching)
#else
            if prefersToolbarPlacement {
                content
                    .modifier(InnerContentModifier(isEnhancedlySearching: $isEnhancedlySearching, isIOSSearching: $isIOSSearching))
                    .searchable(text: $searchText, placement: placement, prompt: promptText)
            } else {
                if isPresented {
                    HStack(spacing: 5) {
                        TextField(prompt ?? "Search", text: $searchText, prompt: promptText)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: "search")
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
                                Text("Cancel")
                                    .padding(.horizontal, 5)
                                    .fixedSize()
                            }
                        }
                    }
                    //                    .fitToReadableContentWidth()
                    .padding(.horizontal, 10)
                    .frame(maxWidth: 850)
                }
                content
                    .environment(\.isEnhancedlySearching, isEnhancedlySearching)
            }
#endif
        }
        .onChange(of: searchText) { searchText in
            onSearchTextChange(searchText: searchText)
        }
        .onChange(of: isPresented) { [oldValue = isPresented] isPresented in
            guard isPresented, oldValue != isPresented else { return }
            withAnimation {
                focusedField = "search"
            }
        }
        .environment(\.isEnhancedlySearching, isEnhancedlySearching)
    }
    
    private func onSearchTextChange(searchText: String) {
        Task { @MainActor in
            let isTextEmpty = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
#if os(iOS)
            isEnhancedlySearching = isIOSSearching || !isTextEmpty
#else
            isEnhancedlySearching = !isTextEmpty
#endif
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
    func enhancedSearchable(isPresented: Binding<Bool>? = nil, searchText: Binding<String>, autosaveName: String, prompt: String? = nil, placement: SearchFieldPlacement = .automatic, prefersToolbarPlacement: Bool = true, searchAction: @escaping ((String) -> Void)) -> some View {
        self.modifier(EnhancedSearchableModifier(isPresented: isPresented ?? .constant(true), canHide: isPresented != nil, searchText: searchText, autosaveName: autosaveName, prompt: prompt, placement: placement, prefersToolbarPlacement: prefersToolbarPlacement, searchAction: searchAction))
    }
}
