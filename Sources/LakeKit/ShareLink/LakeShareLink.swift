//import SwiftBackports

#if os(macOS) || os(iOS)
import SwiftUI
#if canImport(LinkPresentation)
import LinkPresentation
#endif

//@available(iOS, deprecated: 16)
//@available(macOS, deprecated: 13)
//@available(watchOS, deprecated: 9)
//@available(tvOS, unavailable)
//public extension Backport where Wrapped == Any {
    public struct LakeShareLink<Data, PreviewImage, PreviewIcon, Label>: View where Data: RandomAccessCollection, Data.Element: Shareable, Label: View {
        @Binding public var activity: ActivityItem<Data>?

        let label: Label
        let data: Data
        let subject: String?
        let message: String?
        let preview: (Data.Element) -> SharePreview<PreviewImage, PreviewIcon>

        public init(
            activity: Binding<ActivityItem<Data>?>,
            label: Label = DefaultShareLinkLabel(),
            data: Data,
            subject: String?,
            message: String? = nil,
            preview: @escaping (Data.Element) -> SharePreview<PreviewImage, PreviewIcon>
        ) {
            _activity = activity
            self.label = label
            self.data = data
            self.subject = subject
            self.message = message
            self.preview = preview
        }
        
        public init(
            activity: Binding<ActivityItem<Data>?>,
            item: String,
            subject: String? = nil,
            message: String? = nil
        )
        where Data == CollectionOfOne<String>, PreviewImage == Never, PreviewIcon == Never, Label == DefaultShareLinkLabel {
            _activity = activity
            self.label = .init()
            self.data = .init(item)
            self.subject = subject
            self.message = message
            self.preview = { .init($0) }
        }
        
        public init(
            activity: Binding<ActivityItem<Data>?>,
            item: URL,
            subject: String? = nil,
            message: String? = nil
        )
        where Data == CollectionOfOne<URL>, PreviewImage == Never, PreviewIcon == Never, Label == DefaultShareLinkLabel {
            _activity = activity
            self.label = .init()
            self.data = .init(item)
            self.subject = subject
            self.message = message
            self.preview = { .init($0.absoluteString) }
        }
        
        public init(
            activity: Binding<ActivityItem<Data>?>,
            item: String,
            subject: String? = nil,
            message: String? = nil,
            @ViewBuilder label: () -> Label
        )
        where PreviewIcon == Never, PreviewImage == Never, Data == CollectionOfOne<String> {
            _activity = activity
            self.label = label()
            self.data = .init(item)
            self.subject = subject
            self.message = message
            self.preview = { .init($0) }
        }
        
        public init(
            activity: Binding<ActivityItem<Data>?>,
            item: URL,
            subject: String? = nil,
            message: String? = nil,
            @ViewBuilder label: () -> Label
        )
        where PreviewIcon == Never, PreviewImage == Never, Data == CollectionOfOne<URL> {
            _activity = activity
            self.label = label()
            self.data = .init(item)
            self.subject = subject
            self.message = message
            self.preview = { .init($0.absoluteString) }
        }

        public var body: some View {
            Button {
                activity = ActivityItem(data: data)
            } label: {
                label
            }
//            .shareSheet(item: $activity)
        }
    }
//}

//final class TransferableActivityProvider<Data: Shareable, Image: View, Icon: View>: UIActivityItemProvider {
//    let title: String?
//    let subject: String?
//    let message: String?
//    let image: Image?
//    let icon: Icon?
//    let data: Data
//
//    init(data: Data, title: String?, subject: String?, message: String?, image: Image?, icon: Icon?) {
//        self.title = title
//        self.subject = subject
//        self.message = message
//        self.image = image
//        self.icon = icon
//        self.data = data
//
//        let url = URL(fileURLWithPath: NSTemporaryDirectory())
//            .appendingPathComponent("tmp")
//            .appendingPathExtension(data.pathExtension)
//
//        super.init(placeholderItem: url)
//    }
//
//    override var item: Any {
//        data.itemProvider as Any
//    }
//
//    override func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
//        let metadata = LPLinkMetadata()
//        metadata.title = title
////        let icon = ImageRenderer(content: activity.icon)
////        metadata.iconProvider = NSItemProvider(object: UIImage())
////        metadata.imageProvider = NSItemProvider(object: UIImage())
//        return metadata
//    }
//
//    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String { subject ?? "" }
//
//}
#endif
