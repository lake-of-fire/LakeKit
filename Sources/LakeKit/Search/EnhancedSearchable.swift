import SwiftUI
import DSFSearchField
import DebouncedOnChange

private func logLookupKeyboardSearch(
    _ stage: String,
    autosaveName: String?,
    prompt: String?,
    result: String
) {
    debugPrint(
        "# LOOKUPKEYBOARD",
        [
            "stage": stage,
            "autosaveName": autosaveName as Any,
            "prompt": prompt as Any,
            "result": result
        ] as [String: Any]
    )
}

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
    @State private var isSearchFieldEditing = false
    @State private var searchFieldFocusRequestID = 0
#endif
    
    private var promptText: Text? {
        guard let prompt = prompt else { return nil }
        return Text(prompt)
    }
    
    @State private var searchTask: Task<Void, Never>?
    @State private var shouldClear = false
#if os(macOS)
    @FocusState private var focusedField: String?
#endif
    
    public func body(content: Content) -> some View {
        let shouldShowCancelButton = isPresented && (canHide || isEnhancedlySearching || {
#if os(macOS)
            focusedField == "search"
#else
            isSearchFieldEditing
#endif
        }())

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
                            leftSystemImage: "magnifyingglass",
                            focusRequestID: searchFieldFocusRequestID,
                            onEditingChanged: { isEditing in
                                logLookupKeyboardSearch(
                                    "enhancedSearchable.searchFieldEditing",
                                    autosaveName: autosaveName,
                                    prompt: prompt,
                                    result: "value=\(isEditing)"
                                )
                                isSearchFieldEditing = isEditing
                                if isEditing, !isEnhancedlySearching {
                                    isEnhancedlySearching = true
                                }
                            }
                        )
                        .submitLabel(.search)
#endif
                    }
#if os(macOS)
                    .focused($focusedField, equals: "search")
#endif
                    if shouldShowCancelButton {
#if os(macOS)
                        Button("Done") {
                            shouldClear = true
                            isPresented = false
                            isEnhancedlySearching = false
                        }
                        .buttonStyle(.borderless)
#else
                        Button {
                            logLookupKeyboardSearch(
                                "enhancedSearchable.cancelTapped",
                                autosaveName: autosaveName,
                                prompt: prompt,
                                result: "searchTextLength=\(searchText.count)"
                            )
                            withAnimation {
                                isEnhancedlySearching = false
                                isSearchFieldEditing = false
                                isPresented = false
                            }
                            searchText = ""
                        } label: {
                            Text("Cancel")
                                .padding(.horizontal, 5)
                                .fixedSize()
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    logLookupKeyboardSearch(
                                        "enhancedSearchable.cancelPressBegan",
                                        autosaveName: autosaveName,
                                        prompt: prompt,
                                        result: "searchTextLength=\(searchText.count)"
                                    )
                                }
                                .onEnded { _ in
                                    logLookupKeyboardSearch(
                                        "enhancedSearchable.cancelPressEnded",
                                        autosaveName: autosaveName,
                                        prompt: prompt,
                                        result: "searchTextLength=\(searchText.count)"
                                    )
                                }
                        )
#endif
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 850)
                .transition(.opacity)
            }
            
            content
        }
        .onDisappear {
#if os(macOS)
            let disappearResult = "focusedField=nil"
#else
            let disappearResult = "isSearchFieldEditing=false"
#endif
            logLookupKeyboardSearch(
                "enhancedSearchable.onDisappear",
                autosaveName: autosaveName,
                prompt: prompt,
                result: disappearResult
            )
            Task { @MainActor in
#if os(macOS)
                focusedField = nil
#else
                isSearchFieldEditing = false
#endif
            }
        }
        .onChange(of: searchText) { searchText in
            logLookupKeyboardSearch(
                "enhancedSearchable.searchText",
                autosaveName: autosaveName,
                prompt: prompt,
                result: "length=\(searchText.count)"
            )
            updateSearchingStatus(forSearchText: searchText)
        }
        .onChange(of: searchText, debounceTime: 0.18) { searchText in
            onSearchTextChange(searchText: searchText)
        }
#if os(iOS)
        .onChange(of: isPresented) { [oldValue = isPresented] isPresented in
            logLookupKeyboardSearch(
                "enhancedSearchable.isPresented",
                autosaveName: autosaveName,
                prompt: prompt,
                result: "oldValue=\(oldValue); newValue=\(isPresented)"
            )
            guard isPresented, oldValue != isPresented else {
                searchText.removeAll()
                return
            }
            Task { @MainActor in
                logLookupKeyboardSearch(
                    "enhancedSearchable.focusRequest",
                    autosaveName: autosaveName,
                    prompt: prompt,
                    result: "reason=iOS.onChange(isPresented); nextID=\(searchFieldFocusRequestID + 1)"
                )
                searchFieldFocusRequestID &+= 1
            }
        }
        .onChange(of: isEnhancedlySearching) { isEnhancedlySearching in
            logLookupKeyboardSearch(
                "enhancedSearchable.isEnhancedlySearching",
                autosaveName: autosaveName,
                prompt: prompt,
                result: "value=\(isEnhancedlySearching); isSearchFieldEditing=\(isSearchFieldEditing)"
            )
        }
#endif
        .environment(\.isEnhancedlySearching, isEnhancedlySearching)
    }
    
    private func updateSearchingStatus(forSearchText searchText: String) {
        Task { @MainActor in
            let isTextEmpty = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let nextIsEnhancedlySearching: Bool
#if os(iOS)
            nextIsEnhancedlySearching = isPresented || !isTextEmpty
#else
            nextIsEnhancedlySearching = !isTextEmpty
#endif
            if isEnhancedlySearching != nextIsEnhancedlySearching {
                let searchStatusLogResult: String
#if os(iOS)
                searchStatusLogResult = "nextValue=\(nextIsEnhancedlySearching); isTextEmpty=\(isTextEmpty); isPresented=\(isPresented); isSearchFieldEditing=\(isSearchFieldEditing)"
#else
                searchStatusLogResult = "nextValue=\(nextIsEnhancedlySearching); isTextEmpty=\(isTextEmpty); focusedField=\(String(describing: focusedField))"
#endif
                logLookupKeyboardSearch(
                    "enhancedSearchable.updateSearchingStatus",
                    autosaveName: autosaveName,
                    prompt: prompt,
                    result: searchStatusLogResult
                )
                isEnhancedlySearching = nextIsEnhancedlySearching
            }
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
