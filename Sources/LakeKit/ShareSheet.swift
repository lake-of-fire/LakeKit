//// Forked from https://github.com/shaps80/SwiftUIBackports/blob/556d42f391b74059a354b81b8c8e19cc7cb576f4/Sources/SwiftUIBackports/Shared/ShareLink/ShareSheet.swift#L7
//import SwiftUI
//import SwiftBackports
//#if canImport(LinkPresentation)
//import LinkPresentation
//#endif
//
//@available(iOS, deprecated: 16)
//@available(macOS, deprecated: 13)
//@available(watchOS, deprecated: 9)
//@available(tvOS, unavailable)
//public extension Backport where Wrapped == Any {
//    struct ShareLink<Data, PreviewImage, PreviewIcon, Label>: View where Data: RandomAccessCollection, Data.Element: Shareable, Label: View {
//        @State private var activity: ActivityItem<Data>?
//
//        let label: Label
//        let data: Data
//        let subject: String?
//        let message: String?
//        let preview: (Data.Element) -> SharePreview<PreviewImage, PreviewIcon>
//
//        public var body: some View {
//            Button {
//                activity = ActivityItem(data: data)
//            } label: {
//                label
//            }
//            .shareSheet(item: $activity)
//        }
//    }
//}
//
///// TEMPORARY, DO NOT RELY ON THIS!
/////
///// - Note: This **will be removed** in an upcoming release, regardless of semantic versioning
//@available(iOS, message: "This **will be removed** in an upcoming release, regardless of semantic versioning")
//@available(macOS, message: "This **will be removed** in an upcoming release, regardless of semantic versioning")
//public protocol Shareable {
//    var pathExtension: String { get }
//    var itemProvider: NSItemProvider? { get }
//}
//
//public struct ActivityItem<Data> where Data: RandomAccessCollection, Data.Element: Shareable {
//    internal var data: Data
//}
//
//#if os(macOS) || os(iOS)
//public extension View {
//    @ViewBuilder
//    func shareSheet<Data>(item activityItems: Binding<ActivityItem<Data>?>) -> some View where Data: RandomAccessCollection, Data.Element: Shareable {
//#if os(macOS)
//        background(ShareSheet(item: activityItems))
//#elseif os(iOS)
//        background(ShareSheet(item: activityItems))
//#endif
//    }
//}
//#endif
//
//#if os(macOS)
//
//private struct ShareSheet<Data>: NSViewRepresentable where Data: RandomAccessCollection, Data.Element: Shareable {
//    @Binding var item: ActivityItem<Data>?
//
//    public func makeNSView(context: Context) -> SourceView {
//        SourceView(item: $item)
//    }
//
//    public func updateNSView(_ view: SourceView, context: Context) {
//        view.item = $item
//    }
//
//    final class SourceView: NSView, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
//        var picker: NSSharingServicePicker?
//
//        var item: Binding<ActivityItem<Data>?> {
//            didSet {
//                updateControllerLifecycle(
//                    from: oldValue.wrappedValue,
//                    to: item.wrappedValue
//                )
//            }
//        }
//
//        init(item: Binding<ActivityItem<Data>?>) {
//            self.item = item
//            super.init(frame: .zero)
//        }
//
//        required init?(coder: NSCoder) {
//            fatalError("init(coder:) has not been implemented")
//        }
//
//        private func updateControllerLifecycle(from oldValue: ActivityItem<Data>?, to newValue: ActivityItem<Data>?) {
//            switch (oldValue, newValue) {
//            case (.none, .some):
//                presentController()
//            case (.some, .none):
//                dismissController()
//            case (.some, .some), (.none, .none):
//                break
//            }
//        }
//
//        func presentController() {
//            picker = NSSharingServicePicker(items: item.wrappedValue?.data.map { $0 } ?? [])
//            picker?.delegate = self
//            DispatchQueue.main.async {
//                guard self.window != nil else { return }
//                self.picker?.show(relativeTo: self.bounds, of: self, preferredEdge: .minY)
//            }
//        }
//
//        func dismissController() {
//            item.wrappedValue = nil
//        }
//
//        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
//            return self
//        }
//
//        public func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
//            sharingServicePicker.delegate = nil
//            dismissController()
//        }
//
//        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
//            proposedServices
//        }
//    }
//}
//
//#elseif os(iOS)
//
//private struct ShareSheet<Data>: UIViewControllerRepresentable where Data: RandomAccessCollection, Data.Element: Shareable {
//    @Binding var item: ActivityItem<Data>?
//
//    init(item: Binding<ActivityItem<Data>?>) {
//        _item = item
//    }
//
//    func makeUIViewController(context: Context) -> Representable {
//        Representable(item: $item)
//    }
//
//    func updateUIViewController(_ controller: Representable, context: Context) {
//        controller.item = $item
//    }
//}
//
//private extension ShareSheet {
//    final class Representable: UIViewController, UIAdaptivePresentationControllerDelegate, UISheetPresentationControllerDelegate {
//        private weak var controller: UIActivityViewController?
//
//        var item: Binding<ActivityItem<Data>?> {
//            didSet {
//                updateControllerLifecycle(
//                    from: oldValue.wrappedValue,
//                    to: item.wrappedValue
//                )
//            }
//        }
//
//        init(item: Binding<ActivityItem<Data>?>) {
//            self.item = item
//            super.init(nibName: nil, bundle: nil)
//        }
//
//        required init?(coder: NSCoder) {
//            fatalError("init(coder:) has not been implemented")
//        }
//
//        private func updateControllerLifecycle(from oldValue: ActivityItem<Data>?, to newValue: ActivityItem<Data>?) {
//            switch (oldValue, newValue) {
//            case (.none, .some):
//                presentController()
//            case (.some, .none):
//                dismissController()
//            case (.some, .some), (.none, .none):
//                break
//            }
//        }
//
//        private func presentController() {
//            let controller = UIActivityViewController(activityItems: item.wrappedValue?.data.map { $0 } ?? [], applicationActivities: nil)
//            controller.presentationController?.delegate = self
//            controller.popoverPresentationController?.permittedArrowDirections = .any
//            controller.popoverPresentationController?.sourceRect = view.bounds
//            controller.popoverPresentationController?.sourceView = view
//            controller.completionWithItemsHandler = { [weak self] _, _, _, _ in
//                self?.item.wrappedValue = nil
//                self?.dismiss(animated: true)
//            }
//            present(controller, animated: true)
//            self.controller = controller
//        }
//
//        private func dismissController() {
//            guard let controller else { return }
//            controller.presentingViewController?.dismiss(animated: true)
//        }
//
//        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
//            dismissController()
//        }
//    }
//}
//#endif
