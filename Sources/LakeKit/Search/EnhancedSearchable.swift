import SwiftUI
import DSFSearchField
import DebouncedOnChange

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
    @Binding var isEnhancedlySearching: Bool
    let canHide: Bool
    @Binding var searchText: String
    let autosaveName: String?
    let prompt: String?
    let placement: SearchFieldPlacement
    var prefersToolbarPlacement = true
    var showSearchButtonIfNeeded = true
    var canHideSearchBar = false
    let searchAction: ((String) async throws -> Void)
    
#if os(iOS)
    //    @State private var isIOSSearching = false
    @State private var isExecutingSearchFieldFocusWorkaround = false
#endif
    
    private var promptText: Text? {
        guard let prompt = prompt else { return nil }
        return Text(prompt)
    }
    
    @State private var searchTask: Task<Void, Never>?
    @State private var shouldClear = false
    @FocusState private var focusedField: String?
    
    public func body(content: Content) -> some View {
        VStack {
            if isPresented {
                HStack {
                    Group {
#if os(macOS)
                        DSFSearchField.SwiftUI(text: $searchText, shouldClear: $shouldClear, placeholderText: prompt, autosaveName: autosaveName, onSearchTermChange: { searchText in
                            Task { @MainActor in
                                if self.searchText != searchText {
                                    self.searchText = searchText
                                }
                            }
                        })
                        .onExitCommand {
                            shouldClear = true
                            isPresented = false
                            isEnhancedlySearching = false
                        }
#else
                        RoundedTextField(
                            text: $searchText,
                            placeholder: prompt ?? "Search",
                            leftSystemImage: "magnifyingglass"
                        )
                        .submitLabel(.search)
#endif
                    }
                    .focused($focusedField, equals: "search")
                    if isPresented && (canHide || isEnhancedlySearching || focusedField == "search") {
#if os(macOS)
                        Button("Done") {
                            shouldClear = true
                            isPresented = false
                            isEnhancedlySearching = false
                        }
                        .buttonStyle(.borderless)
#else
                        Button {
                            withAnimation {
                                isEnhancedlySearching = false
                                focusedField = nil
                                isPresented = false
                            }
                            searchText = ""
                        } label: {
                            Text("Cancel")
                                .padding(.horizontal, 5)
                                .fixedSize()
                        }
#endif
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 850)
                .transition(.opacity)
            }
            
            content
                .onChange(of: isPresented) { [oldValue = isPresented] isPresented in
                    guard isPresented, oldValue != isPresented else { return }
                    Task { @MainActor in
                        focusedField = "search"
                    }
                }
        }
        .onDisappear {
            Task { @MainActor in
                focusedField = nil
            }
        }
        .onChange(of: searchText) { searchText in
            updateSearchingStatus(forSearchText: searchText)
        }
        .onChange(of: searchText, debounceTime: 0.18) { searchText in
            onSearchTextChange(searchText: searchText)
        }
#if os(iOS)
        .onChange(of: focusedField) { focusedField in
            if !isEnhancedlySearching, focusedField == "search" {
                isEnhancedlySearching = true
            }
        }
        .onChange(of: isPresented) { [oldValue = isPresented] isPresented in
            guard isPresented, oldValue != isPresented else {
                searchText.removeAll()
                return
            }
            Task { @MainActor in
                focusedField = "search"
            }
        }
        .onChange(of: isEnhancedlySearching) { isEnhancedlySearching in
            if isEnhancedlySearching {
                focusedField = "search"
            }
        }
#endif
        .environment(\.isEnhancedlySearching, isEnhancedlySearching)
    }
    
    private func updateSearchingStatus(forSearchText searchText: String) {
        Task { @MainActor in
            let isTextEmpty = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
#if os(iOS)
            isEnhancedlySearching = focusedField == "search" || !isTextEmpty
#else
            isEnhancedlySearching = !isTextEmpty
#endif
        }
    }
    
    private func onSearchTextChange(searchText: String) {
        searchTask?.cancel()
        searchTask = Task.detached {
            do {
                try Task.checkCancellation()
                try await searchAction(searchText)
            } catch { }
        }
    }
}

#if os(iOS)
struct CustomSpacingLabel: LabelStyle {
    var spacing: Double = 0.0
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}
#endif

public extension View {
    func enhancedSearchable(
        isPresented: Binding<Bool>? = nil,
        isEnhancedlySearching: Binding<Bool>,
        searchText: Binding<String>,
        autosaveName: String? = nil,
        prompt: String? = nil,
        placement: SearchFieldPlacement = .automatic,
        prefersToolbarPlacement: Bool = true,
        showSearchButtonIfNeeded: Bool = true,
        canHideSearchBar: Bool = false,
        searchAction: @escaping ((String) async throws -> Void)
    ) -> some View {
        self.modifier(
            EnhancedSearchableModifier(
                isPresented: isPresented ?? .constant(true),
                isEnhancedlySearching: isEnhancedlySearching,
                canHide: isPresented != nil,
                searchText: searchText,
                autosaveName: autosaveName,
                prompt: prompt,
                placement: placement,
                prefersToolbarPlacement: prefersToolbarPlacement,
                showSearchButtonIfNeeded: showSearchButtonIfNeeded,
                canHideSearchBar: canHideSearchBar,
                searchAction: searchAction
            )
        )
    }
}
