import SwiftUI

struct IsEnhancedlySearchingKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var isEnhancedlySearching: Bool {
        get { self[IsEnhancedlySearchingKey.self] }
        set { self[IsEnhancedlySearchingKey.self] = newValue }
    }
}

public enum EnhancedSearchPlacement {
    case contentTop
    case native(SearchFieldPlacement)
}

enum EnhancedSearchablePlatformPolicy {
    static func resolvedPlacement(_ requestedPlacement: EnhancedSearchPlacement) -> EnhancedSearchPlacement {
#if os(macOS)
        .contentTop
#else
        requestedPlacement
#endif
    }

    static func canHide(hasPresentationBinding: Bool) -> Bool {
#if os(macOS)
        false
#else
        hasPresentationBinding
#endif
    }
}

private struct EnhancedSearchIntent: Equatable {
    let text: String
    let autosaveName: String?
    let usesContentTop: Bool
}

public struct EnhancedSearchableModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var isEnhancedlySearching: Bool
    let canHide: Bool
    @Binding var searchText: String
    let autosaveName: String?
    let prompt: String?
    let placement: EnhancedSearchPlacement
    let searchAction: @Sendable (String) async throws -> Void
    
#if os(iOS)
    //    @State private var isIOSSearching = false
    @State private var isExecutingSearchFieldFocusWorkaround = false
#endif
    
    private var promptText: Text? {
        guard let prompt = prompt else { return nil }
        return Text(prompt)
    }
    
    @State private var searchCoordinator: EnhancedSearchRequestCoordinator?
    @State private var isSearchHostVisible = false
    @State private var needsSearchOnAppearance = false
#if os(macOS)
    @State private var searchFieldOwnerRevision = 0
    @State private var searchClearRequest: UUID?
#endif
    @FocusState private var focusedField: String?

    private var searchIntent: EnhancedSearchIntent {
        let usesContentTop: Bool
        switch placement {
        case .contentTop: usesContentTop = true
        case .native: usesContentTop = false
        }
        return EnhancedSearchIntent(text: searchText, autosaveName: autosaveName, usesContentTop: usesContentTop)
    }

    private var showsContentTopSearchField: Bool {
        guard case .contentTop = placement else { return false }
#if os(macOS)
        return true
#else
        return isPresented
#endif
    }

    private var showsDismissButton: Bool {
#if os(macOS)
        canHide && isPresented && (isEnhancedlySearching || focusedField == "search")
#else
        isPresented && (canHide || isEnhancedlySearching || focusedField == "search")
#endif
    }
    
    public func body(content: Content) -> some View {
        VStack {
            if showsContentTopSearchField {
                HStack {
                    Group {
#if os(macOS)
                        EnhancedMacSearchField(
                            text: $searchText,
                            placeholder: prompt,
                            autosaveName: autosaveName,
                            isHostVisible: { isSearchHostVisible },
                            isPresented: { isPresented },
                            ownerRevision: { searchFieldOwnerRevision },
                            clearRequest: { searchClearRequest }
                        )
                        .frame(maxWidth: .infinity)
                        .onExitCommand(perform: clearMacSearch)
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
                    if showsDismissButton {
#if os(macOS)
                        Button("Done", action: clearMacSearch)
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
                .transition(.opacity)
            }
            
            content
                .onChange(of: isPresented) { [oldValue = isPresented] newValue in
                    guard oldValue != newValue, isPresented == newValue else { return }
                    if newValue {
                        if case .contentTop = placement {
                            Task { @MainActor in
                                focusedField = "search"
                            }
                        }
                        if case .native = placement {
                            Task { @MainActor in
                                if isEnhancedlySearching == false {
                                    isEnhancedlySearching = true
                                }
                            }
                        }
                    } else {
                        // Closing: end the search session
#if os(macOS)
                        searchFieldOwnerRevision &+= 1
#endif
                        let hadQuery = !searchText.isEmpty
                        let hadRequest = searchCoordinator?.cancel() == true
                        searchText.removeAll()
                        if searchText.isEmpty {
                            isEnhancedlySearching = false
                        }
                        if case .contentTop = placement {
                            Task { @MainActor in
                                focusedField = nil
                            }
                        }
                        // Native search can publish the text clear before the
                        // presentation change. Preserve its pending reset.
                        if hadQuery || hadRequest { scheduleSearch(for: searchIntent) }
                    }
                }
        }
        .applyNativeSearchableIfNeeded(
            placement: placement,
            searchText: $searchText,
            isPresented: $isPresented,
            canHide: canHide,
            prompt: promptText
        )
        .nativeSearchObserverIfNeeded(
            placement: placement,
            isEnhancedlySearching: $isEnhancedlySearching
        )
        .onAppear {
            isSearchHostVisible = true
            if needsSearchOnAppearance { scheduleSearch(for: searchIntent) }
        }
        .onDisappear {
            isSearchHostVisible = false
#if os(macOS)
            searchFieldOwnerRevision &+= 1
#endif
            if searchCoordinator?.cancel() == true {
                needsSearchOnAppearance = true
            }
            Task { @MainActor in
                focusedField = nil
            }
        }
        .onChange(of: searchIntent) { [previous = searchIntent] intent in
            guard intent == searchIntent else { return }
#if os(macOS)
            if previous.autosaveName != intent.autosaveName || previous.usesContentTop != intent.usesContentTop {
                searchFieldOwnerRevision &+= 1
            }
#endif
            if previous.text != intent.text { updateSearchingStatus(forSearchText: intent.text) }
            scheduleSearch(for: intent)
        }
#if os(iOS)
        .onChange(of: focusedField) { focusedField in
            guard case .contentTop = placement else { return }
            if !isEnhancedlySearching, focusedField == "search" {
                isEnhancedlySearching = true
            }
        }
        .onChange(of: isPresented) { [oldValue = isPresented] isPresented in
            guard case .contentTop = placement else { return }
            guard isPresented, oldValue != isPresented else { return }
            Task { @MainActor in
                focusedField = "search"
            }
        }
        .onChange(of: isEnhancedlySearching) { isEnhancedlySearching in
            guard case .contentTop = placement else { return }
            if isEnhancedlySearching {
                focusedField = "search"
            }
        }
#endif
        .environment(\.isEnhancedlySearching, isEnhancedlySearching)
    }
    
#if os(macOS)
    @MainActor
    private func clearMacSearch() {
        searchFieldOwnerRevision &+= 1
        let hadQuery = !searchText.isEmpty
        let hadRequest = searchCoordinator?.cancel() == true
        searchClearRequest = UUID()
        searchText.removeAll()
        isPresented = false
        isEnhancedlySearching = false
        if hadQuery || hadRequest { scheduleSearch(for: searchIntent) }
    }
#endif

    private func updateSearchingStatus(forSearchText searchText: String) {
        let isTextEmpty = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
#if os(iOS)
        switch placement {
        case .contentTop:
            isEnhancedlySearching = focusedField == "search" || !isTextEmpty
        case .native:
            isEnhancedlySearching = !isTextEmpty || isPresented
        }
#else
        isEnhancedlySearching = !isTextEmpty
#endif
    }
    
    @MainActor
    private func scheduleSearch(for intent: EnhancedSearchIntent) {
        guard isSearchHostVisible else {
            needsSearchOnAppearance = true
            return
        }
        needsSearchOnAppearance = false
        let coordinator = searchCoordinator ?? EnhancedSearchRequestCoordinator()
        if searchCoordinator == nil { searchCoordinator = coordinator }
        coordinator.schedule(searchText: intent.text, admitsRequest: {
            isSearchHostVisible && intent == searchIntent
        }, searchAction: searchAction)
    }
}

private extension View {
    @ViewBuilder
    func applyNativeSearchableIfNeeded(
        placement: EnhancedSearchPlacement,
        searchText: Binding<String>,
        isPresented: Binding<Bool>,
        canHide: Bool,
        prompt: Text?
    ) -> some View {
        switch placement {
        case .contentTop:
            self
        case .native(let searchPlacement):
            if #available(iOS 17, macOS 14, *) {
                if canHide {
                    if let prompt {
                        self.searchable(text: searchText, isPresented: isPresented, placement: searchPlacement, prompt: prompt)
                    } else {
                        self.searchable(text: searchText, isPresented: isPresented, placement: searchPlacement)
                    }
                } else {
                    if let prompt {
                        self.searchable(text: searchText, placement: searchPlacement, prompt: prompt)
                    } else {
                        self.searchable(text: searchText, placement: searchPlacement)
                    }
                }
            } else {
                if let prompt {
                    self.searchable(text: searchText, placement: searchPlacement, prompt: prompt)
                } else {
                    self.searchable(text: searchText, placement: searchPlacement)
                }
            }
        }
    }

    @ViewBuilder
    func nativeSearchObserverIfNeeded(
        placement: EnhancedSearchPlacement,
        isEnhancedlySearching: Binding<Bool>
    ) -> some View {
        switch placement {
        case .contentTop:
            self
        case .native:
            self.background(NativeSearchStateObserver(isEnhancedlySearching: isEnhancedlySearching))
        }
    }
}

private struct NativeSearchStateObserver: View {
    @Binding var isEnhancedlySearching: Bool
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task { updateIfNeeded() }
            .onChange(of: isSearching) { _ in
                updateIfNeeded()
            }
    }

    private func updateIfNeeded() {
        Task { @MainActor in
            if isEnhancedlySearching != isSearching {
                isEnhancedlySearching = isSearching
            }
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
        placement: EnhancedSearchPlacement = .native(.automatic),
        searchAction: @escaping ((String) async throws -> Void)
    ) -> some View {
        let resolvedIsPresented = isPresented ?? .constant(true)
        let resolvedCanHide = EnhancedSearchablePlatformPolicy.canHide(
            hasPresentationBinding: isPresented != nil
        )
        let resolvedPlacement = EnhancedSearchablePlatformPolicy.resolvedPlacement(placement)
        return self.modifier(
            EnhancedSearchableModifier(
                isPresented: resolvedIsPresented,
                isEnhancedlySearching: isEnhancedlySearching,
                canHide: resolvedCanHide,
                searchText: searchText,
                autosaveName: autosaveName,
                prompt: prompt,
                placement: resolvedPlacement,
                searchAction: searchAction
            )
        )
    }
}
