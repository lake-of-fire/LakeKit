import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

#if os(macOS) || os(iOS)
public extension View {
    @ViewBuilder
    func shareSheet<Data>(item activityItems: Binding<ActivityItem<Data>?>) -> some View
    where Data: RandomAccessCollection, Data.Element: Shareable {
        background(ShareSheet(item: activityItems))
    }
}
#endif

#if os(macOS)
struct ShareSheet<Data>: NSViewRepresentable where Data: RandomAccessCollection, Data.Element: Shareable {
    @Binding var item: ActivityItem<Data>?

    func makeNSView(context: Context) -> SourceView {
        SourceView(item: $item)
    }

    func updateNSView(_ view: SourceView, context: Context) {
        view.item = $item
    }

    static func dismantleNSView(_ view: SourceView, coordinator: ()) {
        view.tearDown()
    }

    final class SourceView: NSView, @preconcurrency NSSharingServicePickerDelegate,
                            @preconcurrency NSSharingServiceDelegate {
        var item: Binding<ActivityItem<Data>?> { didSet { updateItem() } }
        private var state = ShareSheetPresentationState()
        private var picker: NSSharingServicePicker?
        private weak var presentationWindow: NSWindow?
        private var isTornDown = false

        /// Native component tests can exercise the real view and its delegates without showing a menu.
        private let showPicker: (NSSharingServicePicker, NSView) -> Void

        init(
            item: Binding<ActivityItem<Data>?>,
            showPicker: @escaping (NSSharingServicePicker, NSView) -> Void = {
                $0.show(relativeTo: $1.bounds, of: $1, preferredEdge: .minY)
            }
        ) {
            self.item = item
            self.showPicker = showPicker
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateItem()
        }

        func updateItem() {
            guard !isTornDown else { return }
            let request = item.wrappedValue
            let host = window
            let hostIsReady = host != nil && (state.current == nil || presentationWindow === host)
            switch state.update(requestID: request?.presentationID, hostIsReady: hostIsReady) {
            case .none:
                break
            case .dismiss(let token):
                closePicker()
                if state.didDismiss(token) { updateItem() }
            case .present(let token):
                guard let request, let host else { return }
                presentationWindow = host
                let sharingItems = request.data.map(\.sharingItem)
                let newPicker = NSSharingServicePicker(items: sharingItems)
                // A Shareable can synchronously replace the request or remove this view.
                guard ownsPresentation(token, in: host) else {
                    updateItem()
                    return
                }
                picker = newPicker
                newPicker.delegate = self
                DispatchQueue.main.async { [weak self, weak newPicker, weak host] in
                    guard let self, let newPicker, let host, self.picker === newPicker else { return }
                    guard self.ownsPresentation(token, in: host) else {
                        self.updateItem()
                        return
                    }
                    self.showPicker(newPicker, self)
                }
            }
        }

        private func ownsPresentation(_ token: ShareSheetPresentationState.Token, in host: NSWindow) -> Bool {
            let requestID = item.wrappedValue?.presentationID
            return !isTornDown && window === host && presentationWindow === host
                && state.owns(token, requestID: requestID)
        }

        private func closePicker() {
            let oldPicker = picker
            picker = nil
            presentationWindow = nil
            oldPicker?.delegate = nil
            oldPicker?.close()
        }

        func tearDown() {
            isTornDown = true
            state = ShareSheetPresentationState()
            closePicker()
        }

        func sharingServicePicker(
            _ sender: NSSharingServicePicker,
            delegateFor sharingService: NSSharingService
        ) -> NSSharingServiceDelegate? {
            picker === sender ? self : nil
        }

        func sharingServicePicker(_ sender: NSSharingServicePicker, didChoose service: NSSharingService?) {
            guard picker === sender, let token = state.current, !isTornDown else { return }
            sender.delegate = nil
            picker = nil
            presentationWindow = nil
            if state.completed(token, requestID: item.wrappedValue?.presentationID) {
                item.wrappedValue = nil
            }
            updateItem()
        }
    }
}
#elseif os(iOS)
private struct ShareSheet<Data>: UIViewControllerRepresentable
where Data: RandomAccessCollection, Data.Element: Shareable {
    @Binding var item: ActivityItem<Data>?

    func makeUIViewController(context: Context) -> Representable {
        Representable(item: $item)
    }

    func updateUIViewController(_ controller: Representable, context: Context) {
        controller.item = $item
    }

    static func dismantleUIViewController(_ controller: Representable, coordinator: ()) {
        controller.tearDown()
    }

    final class Representable: UIViewController, UIAdaptivePresentationControllerDelegate {
        var item: Binding<ActivityItem<Data>?> { didSet { updateItem() } }
        private var state = ShareSheetPresentationState()
        private var controller: UIActivityViewController?
        private var isPresenting = false
        private var isTornDown = false

        init(item: Binding<ActivityItem<Data>?>) {
            self.item = item
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            updateItem()
        }

        private var canPresentActivity: Bool {
            viewIfLoaded?.window != nil && presentedViewController == nil && !isBeingDismissed
        }

        func updateItem() {
            guard !isTornDown, !isPresenting else { return }
            let request = item.wrappedValue
            // A full-screen activity may hide the host while still being presented.
            let hostIsReady = controller != nil || canPresentActivity
            switch state.update(requestID: request?.presentationID, hostIsReady: hostIsReady) {
            case .none:
                break
            case .dismiss(let token):
                dismissActivity(token)
            case .present(let token):
                guard let request, let host = viewIfLoaded?.window else { return }
                let sharingItems = request.data.map(\.sharingItem)
                let activity = UIActivityViewController(activityItems: sharingItems, applicationActivities: nil)
                let requestID = item.wrappedValue?.presentationID
                guard !isTornDown, viewIfLoaded?.window === host, canPresentActivity,
                      state.owns(token, requestID: requestID) else {
                    // If the same queued request lost its host, allow a fresh presentation on reattachment.
                    _ = state.completed(token, requestID: nil)
                    updateItem()
                    return
                }
                presentActivity(activity, token: token)
            }
        }

        private func presentActivity(_ activity: UIActivityViewController, token: ShareSheetPresentationState.Token) {
            controller = activity
            activity.popoverPresentationController?.permittedArrowDirections = []
            activity.popoverPresentationController?.sourceRect = CGRect(
                x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0
            )
            activity.popoverPresentationController?.sourceView = view
            activity.presentationController?.delegate = self
            activity.completionWithItemsHandler = { [weak self, weak activity] _, _, _, _ in
                guard let self, let activity else { return }
                self.completeActivity(activity, token: token)
            }

            isPresenting = true
            present(activity, animated: true) { [weak self, weak activity] in
                guard let activity else { return }
                guard let self, !self.isTornDown else {
                    activity.dismiss(animated: false)
                    return
                }
                guard self.controller === activity else { return }
                self.isPresenting = false
                self.updateItem()
            }
        }

        private func dismissActivity(_ token: ShareSheetPresentationState.Token) {
            guard let activity = removeActivity() else {
                if state.didDismiss(token) { updateItem() }
                return
            }

            let finish: () -> Void = { [weak self] in
                guard let self, !self.isTornDown, self.state.didDismiss(token) else { return }
                self.updateItem()
            }
            if activity.presentingViewController != nil {
                activity.dismiss(animated: true, completion: finish)
            } else {
                finish()
            }
        }

        private func completeActivity(
            _ activity: UIActivityViewController,
            token: ShareSheetPresentationState.Token,
            alreadyDismissed: Bool = false
        ) {
            guard !isTornDown, controller === activity, state.current == token else { return }
            _ = removeActivity()
            isPresenting = false
            if state.beginCompletion(token, requestID: item.wrappedValue?.presentationID) {
                item.wrappedValue = nil
            }

            let finish = { [weak self] in
                guard let self, !self.isTornDown, self.state.didDismiss(token) else { return }
                self.updateItem()
            }
            if alreadyDismissed {
                finish()
            } else if activity.isBeingDismissed, let transition = activity.transitionCoordinator,
                      transition.animate(alongsideTransition: nil, completion: { _ in finish() }) {
                // The activity is already dismissing itself.
            } else if activity.presentingViewController != nil {
                activity.dismiss(animated: true, completion: finish)
            } else {
                finish()
            }
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            guard let activity = controller, presentationController.presentedViewController === activity,
                  let token = state.current else { return }
            completeActivity(activity, token: token, alreadyDismissed: true)
        }

        private func removeActivity() -> UIActivityViewController? {
            let activity = controller
            controller = nil
            activity?.completionWithItemsHandler = nil
            activity?.presentationController?.delegate = nil
            return activity
        }

        func tearDown() {
            isTornDown = true
            state = ShareSheetPresentationState()
            let activity = removeActivity()
            if !isPresenting {
                activity?.dismiss(animated: false)
            }
        }
    }
}
#endif
