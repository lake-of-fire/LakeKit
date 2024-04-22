import SwiftUI
import DSFSearchField
@_spi(Advanced) import SwiftUIIntrospect

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
#else
            if prefersToolbarPlacement {
                content
                    .modifier(InnerContentModifier(isEnhancedlySearching: $isEnhancedlySearching, isIOSSearching: $isIOSSearching))
                    .searchable(text: $searchText, placement: placement, prompt: promptText)
            } else {
                if isPresented {
                    if #available(iOS 17, *) {
                        if !isEnhancedlySearching {
                            Button {
                                isEnhancedlySearching = true
                            } label: {
                                HStack(spacing: 0) {
                                    Label(prompt ?? "Search", systemImage: "magnifyingglass")
                                        .labelStyle(CustomSpacingLabel(spacing: 5))
//                                        .fixedSize()
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
                    } else {
                        HStack(spacing: 5) {
                            HStack(spacing: 0) {
                                TextField(prompt ?? "Search", text: $searchText, prompt: promptText)
                                    .foregroundStyle(.secondary)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: "search")
                            }
                            if isEnhancedlySearching {
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
                        .padding(.bottom, 5)
                        .frame(maxWidth: 850)
                    }
                }
                content
                    .modifier {
                        if #available(iOS 17, *) {
                            $0.searchable(text: $searchText, isPresented: Binding(
                                get: {
                                    return true
                                }, set: { newValue in
                                    isEnhancedlySearching = newValue
                                }
                            ), placement: placement, prompt: promptText)
                        } else { $0 }
                    }
//                    .modifier(InnerContentModifier(isEnhancedlySearching: $isEnhancedlySearching, isIOSSearching: $isIOSSearching))
//                    .navigationSearchBar(
//                        text: $searchText,
////                        scopeSelection: $scopeSelection,
//                        options: [
//                            .automaticallyShowsSearchBar: true,
//                            .obscuresBackgroundDuringPresentation: true,
//                            .hidesNavigationBarDuringPresentation: true,
//                            .hidesSearchBarWhenScrolling: false,
//                            .placeholder: prompt ?? "Search",
//                            .showsBookmarkButton: true,
////                            .scopeButtonTitles: ["All", "Missed", "Other"]
//                        ],
//                        actions: [
//                            .onCancelButtonClicked: {
//                                print("Cancel")
//                            },
//                            .onSearchButtonClicked: {
//                                print("Search")
//                            },
////                            .onBookmarkButtonClicked: {
////                                print("Present Bookmarks")
////                            }
//                        ],
//                        searchResultsContent: {
//                            EmptyView()
//                        })
            }
#endif
        }
        .onChange(of: searchText) { searchText in
            onSearchTextChange(searchText: searchText)
        }
        #if os(iOS)
        .onChange(of: focusedField) { focusedField in
            if !isEnhancedlySearching, focusedField == "search" {
                isEnhancedlySearching = true
            }
        }
        #endif
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
    func enhancedSearchable(isPresented: Binding<Bool>? = nil, searchText: Binding<String>, autosaveName: String, prompt: String? = nil, placement: SearchFieldPlacement = .automatic, prefersToolbarPlacement: Bool = true, searchAction: @escaping ((String) -> Void)) -> some View {
        self.modifier(EnhancedSearchableModifier(isPresented: isPresented ?? .constant(true), canHide: isPresented != nil, searchText: searchText, autosaveName: autosaveName, prompt: prompt, placement: placement, prefersToolbarPlacement: prefersToolbarPlacement, searchAction: searchAction))
    }
}
