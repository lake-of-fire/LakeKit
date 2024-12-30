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
    @State private var isIOSSearching = false
    @State private var isExecutingSearchFieldFocusWorkaround = false
#endif
    
    private var promptText: Text? {
        guard let prompt = prompt else { return nil }
        return Text(prompt)
    }
    
    @State private var searchTask: Task<Void, Never>?
    @State private var shouldClear = false
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
                    DSFSearchField.SwiftUI(text: $searchText, shouldClear: $shouldClear, placeholderText: prompt, autosaveName: autosaveName, onSearchTermChange: { searchText in
                        // Sometimes necessary despite searchText binding...
                        Task { @MainActor in
                            if self.searchText != searchText {
                                //                            debugPrint("!! DSF searchterm", searchText)
                                self.searchText = searchText
                            }
                        }
//                        onSearchTextChange(searchText: searchTerm)
                        //                Task { @MainActor in
                        //                    isEnhancedlySearching = !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        //                }
                    })
                    .focused($focusedField, equals: "search")
                    .onExitCommand {
//                        withAnimation(.linear(duration: 0.075)) {
//                            searchText = ""
                        shouldClear = true
                        isPresented = false
                        isEnhancedlySearching = false
                    }
                    
                    if isPresented && (canHide || isEnhancedlySearching) {
                        Button("Done") {
//                            shouldClear = true
//                            withAnimation(.linear(duration: 0.075)) {
//                                searchText = ""
//                                    try await Task.sleep(nanoseconds: UInt64(0.06) * 1_000_000_000)
                            shouldClear = true
                            isPresented = false
                            isEnhancedlySearching = false
//                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 5)
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
            
#else
            if isPresented {
                if canHideSearchBar && showSearchButtonIfNeeded, #available(iOS 17, *) {
                    if !isEnhancedlySearching {
                        Button {
                            isEnhancedlySearching = true
                        } label: {
                            HStack(spacing: 0) {
                                Label(prompt ?? "Search", systemImage: "magnifyingglass")
                                    .labelStyle(CustomSpacingLabel(spacing: 5))
                                Spacer(minLength: 0)
                            }
                            .padding(.top, 0.5)
                            .padding(.bottom, 0.5)
                            .offset(x: -6)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .padding(.horizontal, 16)
                    }
                } else if !prefersToolbarPlacement {
                    HStack(spacing: 5) {
                        HStack(spacing: 0) {
                            TextField(prompt ?? "Search", text: $searchText, prompt: promptText)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: "search")
                        }
                        if isPresented && (canHide || isEnhancedlySearching) {
                            Button {
                                withAnimation {
                                    isEnhancedlySearching = false
                                    focusedField = nil
                                    isPresented = false
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
//                    .padding(.bottom, 5)
                    .frame(maxWidth: 850)
                }
            }
            content
                .modifier(InnerContentModifier(isEnhancedlySearching: $isEnhancedlySearching, isIOSSearching: $isIOSSearching))
                .modifier {
                    if isPresented && prefersToolbarPlacement {
                        if canHideSearchBar, #available(iOS 17, *) {
                            $0.searchable(text: $searchText, isPresented: Binding(
                                get: {
//                                    return isPresented
                                    return isEnhancedlySearching
                                }, set: { newValue in
                                    isEnhancedlySearching = newValue
                                    isPresented = newValue
                                }
                            ), placement: placement, prompt: promptText)
                        } else {
                            $0.searchable(text: $searchText, placement: placement, prompt: promptText)
                        }
                    } else { $0 }
                }
#endif
        }
        .onChange(of: searchText) { searchText in
            updateSearchingStatus(forSearchText: searchText)
        }
        .onChange(of: searchText, debounceTime: 0.18) { searchText in
            onSearchTextChange(searchText: searchText)
        }
#if os(iOS)
//        .onChange(of: focusedField) { [oldValue = focusedField] focusedField in
//            if !isEnhancedlySearching, focusedField == "search" {
//                isEnhancedlySearching = true
//            } else if !isExecutingSearchFieldFocusWorkaround && oldValue == "search" && focusedField != "search" && isEnhancedlySearching {
//                isEnhancedlySearching = false
//                if canHideSearchBar {
//                    isPresented = false
//                }
//            }
//        }
        .onChange(of: isPresented) { [oldValue = isPresented] isPresented in
            guard isPresented, oldValue != isPresented else {
                searchText.removeAll()
                return
            }
            Task { @MainActor in
//                guard !isExecutingSearchFieldFocusWorkaround else { return }
//                debugPrint("!! isExecuting workaround")
//                isExecutingSearchFieldFocusWorkaround = true
//                // Hack to trigger correct focused state triggering.
                focusedField = "search"
//                try await Task.sleep(nanoseconds: UInt64(0.06) * 1_000_000_000)
//                focusedField = nil
//                try await Task.sleep(nanoseconds: UInt64(0.06) * 1_000_000_000)
//                focusedField = "search"
//                isExecutingSearchFieldFocusWorkaround = false
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
            isEnhancedlySearching = isIOSSearching || !isTextEmpty
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
