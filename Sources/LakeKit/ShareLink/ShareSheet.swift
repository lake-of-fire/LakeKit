import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

#if os(macOS) || os(iOS)
public extension View {
    func shareSheet<Data>(item activityItems: Binding<ActivityItem<Data>?>) -> some View
    where Data: RandomAccessCollection, Data.Element: Shareable {
        background(ShareSheet(item: activityItems))
    }
}
#endif

#if os(macOS)
struct ShareSheet<Data>: NSViewRepresentable where Data: RandomAccessCollection, Data.Element: Shareable {
    @Binding var item: ActivityItem<Data>?

    func makeNSView(context: Context) -> SourceView { SourceView(item: $item) }
    func updateNSView(_ view: SourceView, context: Context) { view.item = $item }
    static func dismantleNSView(_ view: SourceView, coordinator: ()) { view.tearDown() }

    final class SourceView: NSView, @preconcurrency NSSharingServicePickerDelegate,
                            @preconcurrency NSSharingServiceDelegate {
        var item: Binding<ActivityItem<Data>?> { didSet { updateItem() } }
        private var state = ShareSheetPresentationState()
        private var picker: NSSharingServicePicker?
        private var isTornDown = false
        // Per-instance seam exercises real attachment/delegate code without
        // opening an operating-system menu in the native component tests.
        private let showPicker: (NSSharingServicePicker, NSView) -> Void

        init(item: Binding<ActivityItem<Data>?>,
             showPicker: @escaping (NSSharingServicePicker, NSView) -> Void = {
                 $0.show(relativeTo: $1.bounds, of: $1, preferredEdge: .minY)
             }) {
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
            switch state.update(requestID: item.wrappedValue?.presentationID, hostIsReady: window != nil) {
            case .none: break
            case .dismiss(let token):
                let oldPicker = picker
                picker = nil
                oldPicker?.delegate = nil
                oldPicker?.close()
                state.didDismiss(token)
                updateItem()
            case .present(let token):
                guard let request = item.wrappedValue else { return }
                let newPicker = NSSharingServicePicker(items: request.data.map(\.sharingItem))
                picker = newPicker
                newPicker.delegate = self
                DispatchQueue.main.async { [weak self, weak newPicker] in
                    guard let self, let newPicker, !self.isTornDown else { return }
                    guard self.picker === newPicker, self.window != nil,
                          self.state.owns(token, requestID: self.item.wrappedValue?.presentationID) else {
                        self.updateItem()
                        return
                    }
                    self.showPicker(newPicker, self)
                }
            }
        }

        func tearDown() {
            isTornDown = true
            let oldPicker = picker
            picker = nil
            oldPicker?.delegate = nil
            oldPicker?.close()
            state = ShareSheetPresentationState()
        }

        func sharingServicePicker(_ sender: NSSharingServicePicker,
                                  delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? { self }
        func sharingServicePicker(_ sender: NSSharingServicePicker, didChoose service: NSSharingService?) {
            guard picker === sender, let token = state.current else { return }
            sender.delegate = nil
            picker = nil
            if state.completed(token, requestID: item.wrappedValue?.presentationID) { item.wrappedValue = nil }
            updateItem()
        }
        func sharingServicePicker(_ sender: NSSharingServicePicker, sharingServicesForItems items: [Any],
                                  proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
            proposedServices
        }
    }
}
#elseif os(iOS)
struct ShareSheet<Data>: UIViewControllerRepresentable where Data: RandomAccessCollection, Data.Element: Shareable {
    @Binding var item: ActivityItem<Data>?

    func makeUIViewController(context: Context) -> Representable { Representable(item: $item) }
    func updateUIViewController(_ controller: Representable, context: Context) { controller.item = $item }
    static func dismantleUIViewController(_ controller: Representable, coordinator: ()) { controller.tearDown() }

    final class Representable: UIViewController, UIAdaptivePresentationControllerDelegate {
        var item: Binding<ActivityItem<Data>?> { didSet { updateItem() } }
        private var state = ShareSheetPresentationState()
        private var controller: UIActivityViewController?
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

        func updateItem() {
            guard !isTornDown else { return }
            // An owned full-screen presentation may hide its presenting view;
            // that alone is not a request to dismiss the activity controller.
            let ready = controller != nil || viewIfLoaded?.window != nil
            switch state.update(requestID: item.wrappedValue?.presentationID, hostIsReady: ready) {
            case .none: break
            case .dismiss(let token):
                guard let oldController = controller else {
                    state.didDismiss(token)
                    updateItem()
                    return
                }
                controller = nil
                oldController.completionWithItemsHandler = nil
                oldController.presentationController?.delegate = nil
                let finish: () -> Void = { [weak self] in
                    guard let self, !self.isTornDown, self.state.didDismiss(token) else { return }
                    self.updateItem()
                }
                if oldController.presentingViewController != nil {
                    // Dismiss exactly the controller we own, not a parent sheet
                    // or a later controller reached through the presentation host.
                    oldController.dismiss(animated: true, completion: finish)
                } else { finish() }
            case .present(let token):
                guard let request = item.wrappedValue else { return }
                let activity = UIActivityViewController(activityItems: request.data.map(\.sharingItem),
                                                        applicationActivities: nil)
                controller = activity
                activity.popoverPresentationController?.permittedArrowDirections = []
                activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX,
                    y: view.bounds.midY, width: 0, height: 0)
                activity.popoverPresentationController?.sourceView = view
                activity.presentationController?.delegate = self
                activity.completionWithItemsHandler = { [weak self, weak activity] _, _, _, _ in
                    guard let self, let activity, self.controller === activity, !self.isTornDown else { return }
                    if self.state.owns(token, requestID: self.item.wrappedValue?.presentationID) {
                        self.item.wrappedValue = nil
                    }
                    self.updateItem()
                }
                present(activity, animated: true)
            }
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            guard presentationController.presentedViewController === controller,
                  let token = state.current, !isTornDown else { return }
            controller = nil
            if state.completed(token, requestID: item.wrappedValue?.presentationID) { item.wrappedValue = nil }
            updateItem()
        }

        func tearDown() {
            isTornDown = true
            let oldController = controller
            controller = nil
            oldController?.completionWithItemsHandler = nil
            oldController?.presentationController?.delegate = nil
            oldController?.dismiss(animated: false)
            state = ShareSheetPresentationState()
        }
    }
}
#endif
