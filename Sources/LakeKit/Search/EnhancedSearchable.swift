import SwiftUI
#if os(macOS)
import DSFSearchField
#endif

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

@MainActor
final class EnhancedSearchRequestCoordinator {
    private var generation: UInt64 = 0
    private var task: Task<Void, Never>?

    @discardableResult
    func schedule(
        searchText: String,
        waitForDebounce: @escaping @Sendable () async throws -> Void = {
            try await Task.sleep(nanoseconds: 180_000_000)
        },
        admitsRequest: @escaping @MainActor () -> Bool,
        searchAction: @escaping @Sendable (String) async throws -> Void
    ) -> Task<Void, Never> {
        cancel()
        let owner = generation
        let operation = Task { @MainActor [weak self] in
            defer {
                if self?.generation == owner { self?.task = nil }
            }
            do {
                try await waitForDebounce()
                try Task.checkCancellation()
                guard let self, self.generation == owner, admitsRequest() else { return }
                // Once invoked, the caller's async operation must honor Task
                // cancellation before publishing its own results.
                try await searchAction(searchText)
            } catch { }
        }
        task = operation
        return operation
    }

    func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
    }
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
    @State private var isSearchFieldEditing = false
    @State private var searchFieldFocusRequestID = 0
#elseif os(macOS)
    @FocusState private var focusedField: String?
#endif
    @State private var searchCoordinator: EnhancedSearchRequestCoordinator?
    @State private var searchChangeID = 0
    @State private var isVisible = false
    @State private var shouldClear = false

    private var promptText: Text? {
        guard let prompt else { return nil }
        return Text(prompt)
    }

    private var usesContentTopPlacement: Bool {
        if case .contentTop = placement { return true }
        return false
    }

    private var showsContentTopSearchField: Bool {
        guard usesContentTopPlacement else { return false }
#if os(macOS)
        return true
#else
        return isPresented
#endif
    }

    private var showsDismissButton: Bool {
#if os(macOS)
        return canHide && isPresented && (isEnhancedlySearching || focusedField == "search")
#else
        return isPresented && (canHide || isEnhancedlySearching || isSearchFieldEditing)
#endif
    }

    public func body(content: Content) -> some View {
        VStack {
            if showsContentTopSearchField {
                HStack {
                    Group {
#if os(macOS)
                        DSFSearchField.SwiftUI(text: $searchText, shouldClear: $shouldClear,
                            placeholderText: prompt, autosaveName: autosaveName, onSearchTermChange: { text in
                                let changeID = searchChangeID
                                Task { @MainActor in
                                    guard isVisible, changeID == searchChangeID else { return }
                                    if self.searchText != text { self.searchText = text }
                                }
                            })
                            .frame(maxWidth: .infinity)
                            .onExitCommand { endSearchSession() }
#else
                        RoundedTextField(
                            text: $searchText,
                            placeholder: prompt ?? "Search",
                            leftSystemImage: "magnifyingglass",
                            focusRequestID: searchFieldFocusRequestID,
                            onEditingChanged: { isEditing in
                                Task { @MainActor in
                                    guard isVisible else { return }
                                    if isEditing, !isPresented { return }
                                    logLookupKeyboardSearch("enhancedSearchable.searchFieldEditing",
                                        autosaveName: autosaveName, prompt: prompt, result: "value=\(isEditing)")
                                    isSearchFieldEditing = isEditing
                                    updateSearchingStatus(forSearchText: searchText)
                                }
                            }
                        )
                        .submitLabel(.search)
#endif
                    }
#if os(macOS)
                    .focused($focusedField, equals: "search")
#endif
                    if showsDismissButton {
#if os(macOS)
                        Button("Done") { endSearchSession() }
                            .buttonStyle(.borderless)
#else
                        Button {
                            logLookupKeyboardSearch("enhancedSearchable.cancelTapped",
                                autosaveName: autosaveName, prompt: prompt,
                                result: "searchTextLength=\(searchText.count)")
                            withAnimation { endSearchSession() }
                        } label: {
                            Text("Cancel").padding(.horizontal, 5).fixedSize()
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
                .transition(.opacity)
            }
            content
        }
        .applyNativeSearchableIfNeeded(
            placement: placement, searchText: $searchText, isPresented: $isPresented,
            canHide: canHide, prompt: promptText
        )
        .nativeSearchObserverIfNeeded(placement: placement, isEnhancedlySearching: $isEnhancedlySearching)
        .onAppear { isVisible = true }
        .onDisappear {
            logLookupKeyboardSearch("enhancedSearchable.onDisappear",
                autosaveName: autosaveName, prompt: prompt, result: "retiringSearchAndFocus")
            isVisible = false
            invalidateSearchWork()
#if os(macOS)
            focusedField = nil
#else
            isSearchFieldEditing = false
#endif
        }
        .onChange(of: usesContentTopPlacement) { usesContentTop in
            invalidateSearchWork()
#if os(macOS)
            focusedField = nil
#else
            isSearchFieldEditing = false
#endif
            if usesContentTop { requestContentTopFocus() }
            onSearchTextChange(searchText: searchText, changeID: searchChangeID)
        }
        .onChange(of: isPresented) { [oldValue = isPresented] newValue in
            logLookupKeyboardSearch("enhancedSearchable.isPresented",
                autosaveName: autosaveName, prompt: prompt,
                result: "oldValue=\(oldValue); newValue=\(newValue)")
            guard oldValue != newValue else { return }
            if newValue {
                switch placement {
                case .contentTop: requestContentTopFocus()
                case .native: isEnhancedlySearching = true
                }
            } else {
                endSearchSession()
            }
        }
        .onChange(of: searchText) { text in
            invalidateSearchWork()
            logLookupKeyboardSearch("enhancedSearchable.searchText",
                autosaveName: autosaveName, prompt: prompt, result: "length=\(text.count)")
            updateSearchingStatus(forSearchText: text)
            onSearchTextChange(searchText: text, changeID: searchChangeID)
        }
#if os(iOS)
        .onChange(of: isEnhancedlySearching) { searching in
            logLookupKeyboardSearch("enhancedSearchable.isEnhancedlySearching",
                autosaveName: autosaveName, prompt: prompt,
                result: "value=\(searching); isSearchFieldEditing=\(isSearchFieldEditing)")
            guard case .contentTop = placement, searching, !isSearchFieldEditing else { return }
            requestContentTopFocus()
        }
#endif
        .environment(\.isEnhancedlySearching, isEnhancedlySearching)
    }

    @MainActor
    private func invalidateSearchWork() {
        searchChangeID &+= 1
        searchCoordinator?.cancel()
    }

    @MainActor
    private func endSearchSession() {
        invalidateSearchWork()
        shouldClear = true
#if os(macOS)
        focusedField = nil
#else
        isSearchFieldEditing = false
#endif
        isEnhancedlySearching = false
        isPresented = false
        searchText.removeAll()
    }

    @MainActor
    private func requestContentTopFocus() {
        guard case .contentTop = placement, isVisible, isPresented else { return }
        let changeID = searchChangeID
        Task { @MainActor in
            guard !Task.isCancelled, isVisible, isPresented, changeID == searchChangeID else { return }
#if os(macOS)
            let result = "reason=contentTopPresentation; focusedField=search"
#else
            let result = "reason=contentTopPresentation; nextID=\(searchFieldFocusRequestID + 1)"
#endif
            logLookupKeyboardSearch("enhancedSearchable.focusRequest",
                autosaveName: autosaveName, prompt: prompt, result: result)
#if os(macOS)
            focusedField = "search"
#else
            searchFieldFocusRequestID &+= 1
#endif
        }
    }

    @MainActor
    private func updateSearchingStatus(forSearchText text: String) {
        let isTextEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let nextIsSearching: Bool
#if os(iOS)
        switch placement {
        case .contentTop: nextIsSearching = isSearchFieldEditing || !isTextEmpty
        case .native: nextIsSearching = !isTextEmpty || isPresented
        }
#else
        nextIsSearching = !isTextEmpty
#endif
        guard isEnhancedlySearching != nextIsSearching else { return }
#if os(iOS)
        let result = "nextValue=\(nextIsSearching); isTextEmpty=\(isTextEmpty); isPresented=\(isPresented); isSearchFieldEditing=\(isSearchFieldEditing)"
#else
        let result = "nextValue=\(nextIsSearching); isTextEmpty=\(isTextEmpty); focusedField=\(String(describing: focusedField))"
#endif
        logLookupKeyboardSearch("enhancedSearchable.updateSearchingStatus",
            autosaveName: autosaveName, prompt: prompt, result: result)
        isEnhancedlySearching = nextIsSearching
    }

    @MainActor
    private func onSearchTextChange(searchText text: String, changeID: Int) {
        guard isVisible, changeID == searchChangeID, text == searchText else { return }
        let coordinator = searchCoordinator ?? EnhancedSearchRequestCoordinator()
        if searchCoordinator == nil { searchCoordinator = coordinator }
        coordinator.schedule(searchText: text, admitsRequest: {
            isVisible && changeID == searchChangeID && text == searchText
                && (!canHide || isPresented || text.isEmpty)
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
            .task(id: isSearching) { @MainActor in
                guard !Task.isCancelled else { return }
                if isEnhancedlySearching != isSearching { isEnhancedlySearching = isSearching }
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
