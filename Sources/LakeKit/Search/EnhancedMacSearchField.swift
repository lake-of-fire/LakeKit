#if os(macOS)
import AppKit
import DSFSearchField
import SwiftUI

/// Retain DSF's native control and recents, but capture native input before
/// deferring its binding write. DSF's SwiftUI wrapper defers the raw write
/// before reporting the edit to its caller.
@MainActor
struct EnhancedMacSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String?
    let autosaveName: String?
    let isHostVisible: @MainActor () -> Bool
    let isPresented: @MainActor () -> Bool
    let ownerRevision: @MainActor () -> Int
    let clearRequest: @MainActor () -> UUID?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> DSFSearchField {
        let field = DSFSearchField(frame: .zero, recentsAutosaveName: autosaveName)
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.searchTermChangeCallback = { [weak coordinator = context.coordinator] value in
            // The raw DSF callback is synchronous with its AppKit value binding.
            MainActor.assumeIsolated { coordinator?.receiveNativeEdit(value) }
        }
        return field
    }

    func updateNSView(_ field: DSFSearchField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.isUpdatingField = true
        defer { coordinator.isUpdatingField = false }

        field.placeholderString = placeholder
        if field.recentsAutosaveName != autosaveName {
            field.recentsAutosaveName = autosaveName
        }
        let request = clearRequest()
        let shouldClear = request != coordinator.handledClearRequest
        coordinator.handledClearRequest = request
        if !coordinator.writeback.hasPendingEdit(from: coordinator.currentInput),
           field.stringValue != text {
            field.stringValue = text
        }
        if shouldClear, text.isEmpty {
            (field.cell as? NSSearchFieldCell)?.cancelButtonCell?.performClick(nil)
        }
    }

    static func dismantleNSView(_ field: DSFSearchField, coordinator: Coordinator) {
        field.searchTermChangeCallback = nil
        coordinator.parent = nil
        coordinator.writeback.cancel()
    }

    @MainActor
    final class Coordinator {
        var parent: EnhancedMacSearchField?
        var handledClearRequest: UUID?
        var isUpdatingField = false
        let writeback = EnhancedSearchFieldWriteback()

        var currentInput: EnhancedSearchFieldWriteback.Input? {
            guard let parent, parent.isHostVisible(),
                  parent.clearRequest() == handledClearRequest else { return nil }
            return .init(
                text: parent.text,
                ownerRevision: parent.ownerRevision(),
                autosaveName: parent.autosaveName,
                isPresented: parent.isPresented()
            )
        }

        func receiveNativeEdit(_ value: String) {
            guard !isUpdatingField else { return }
            writeback.receive(value, currentInput: { [weak self] in self?.currentInput }) { [weak self] value in
                self?.parent?.text = value
            }
        }
    }
}

@MainActor
final class EnhancedSearchFieldWriteback {
    struct Input: Equatable {
        let text: String
        let ownerRevision: Int
        let autosaveName: String?
        let isPresented: Bool

        init(text: String, ownerRevision: Int, autosaveName: String? = nil, isPresented: Bool = false) {
            self.text = text
            self.ownerRevision = ownerRevision
            self.autosaveName = autosaveName
            self.isPresented = isPresented
        }
    }

    private struct Edit {
        let value: String
        let input: Input
        let generation: Int
        let currentInput: @MainActor () -> Input?
        let commit: @MainActor (String) -> Void
    }

    private var generation = 0
    private var pending: Edit?
    private var delivery: Task<Void, Never>?

    func hasPendingEdit(from input: Input?) -> Bool {
        guard let input else { return false }
        return pending?.input == input
    }

    @discardableResult
    func receive(
        _ value: String,
        currentInput: @escaping @MainActor () -> Input?,
        commit: @escaping @MainActor (String) -> Void
    ) -> Task<Void, Never>? {
        let origin = generation
        guard let input = currentInput(), generation == origin else { return nil }
        // Multiple keystrokes can arrive before SwiftUI reads the binding.
        // Commit the latest edit from the still-current model baseline.
        generation &+= 1
        pending = Edit(value: value, input: input, generation: generation, currentInput: currentInput, commit: commit)
        if let delivery { return delivery }
        let delivery = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            let edit = pending
            pending = nil
            self.delivery = nil
            guard let edit, edit.value != edit.input.text,
                  edit.currentInput() == edit.input, generation == edit.generation else { return }
            edit.commit(edit.value)
        }
        self.delivery = delivery
        return delivery
    }

    func cancel() {
        generation &+= 1
        let retired = delivery
        delivery = nil
        pending = nil
        retired?.cancel()
    }
}
#endif
