#if os(macOS)
import SwiftUI
import AppKit
import Quartz

var i = 0

/// A simple class to go between the functional style of SwiftUI and the
/// specific needs for #selectors in NSMenuItem.
///
/// For this to work, you must keep a reference to this Proxy object until the
/// context menu has disappeared.
final class NSMenuItemProxy: NSObject {
    var title: String
    var keyEquivalent: String
    
    typealias Action = () -> Void
    var action: Action?
    
    private var isSeparator: Bool = false
    
    init(title: String, keyEquivalent: String, action: Action?) {
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.action = action
    }
    
    static func separator() -> NSMenuItemProxy {
        let x: Void
        return NSMenuItemProxy(isSeparator: x)
    }
    private init(isSeparator: Void) {
        // Unused
        self.title = ""
        self.keyEquivalent = ""
        self.action = nil
        
        self.isSeparator = true
    }
    
    func createMenuItem() -> NSMenuItem {
        if (isSeparator) {
            return NSMenuItem.separator()
        }
        
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        if (action != nil) {
            item.isEnabled = true
            item.target = self
            item.action = #selector(NSMenuItemProxy.handleAction)
        }
        
        return item
    }
    
    @objc private func handleAction() {
        guard let action = self.action else { return }
        
        action()
    }
}

private final class Cell<Content: View>: NSCollectionViewItem {
    // TODO: also highlight/hover state!
    // TODO: pass to Content
    override var isSelected: Bool {
        didSet {
            if (isSelected) {
                view.layer?.borderColor = NSColor.selectedControlColor.cgColor
                view.layer?.borderWidth = 3
            } else {
                view.layer?.borderColor = NSColor.clear.cgColor
                view.layer?.borderWidth = 0
            }
        }
    }
    
    var contents: NSView?
    let container = NSStackView()
    
    override func loadView() {
        container.orientation = NSUserInterfaceLayoutOrientation.vertical
        container.wantsLayer = true
        
        // For debugging rendering, choose the text field:
        self.view = container
        // self.view = NSTextField(labelWithString: "item \(i)")
        
        // print("Rendering item \(i)")
        i += 1
    }
    
    override func prepareForReuse() {
        // print("prepare for reuse")
        super.prepareForReuse()
    }
    
    // TODO: Double-tap to activate inspector.
    // typealias DoubleTapHandler = (_ event: NSEvent) -> Bool
    // var doubleTapHandler: DoubleTapHandler?
    // override func mouseDown(with event: NSEvent) {
    //     print(event.clickCount)
    //     if event.clickCount == 2, let handler = doubleTapHandler {
    //         if (handler(event)) {
    //             return
    //         }
    //     }
    //
    //     super.mouseDown(with: event)
    // }
}

private final class InternalCollectionView: NSCollectionView {
    // Return whether or not you handled the event
    typealias KeyDownHandler = (_ event: NSEvent) -> Bool
    var keyDownHandler: KeyDownHandler? = nil
    
    typealias ContextMenuItemsGenerator = (_ items: [IndexPath]) -> [NSMenuItemProxy]
    var contextMenuItemsGenerator: ContextMenuItemsGenerator? = nil
    var currentContextMenuItemProxies: [NSMenuItemProxy] = []
    
    override func keyDown(with event: NSEvent) {
        if let keyDownHandler = keyDownHandler {
            let didHandle = keyDownHandler(event)
            if (didHandle) {
                return
            }
        }
        
        super.keyDown(with: event)
    }
}

// // Context menus!
// extension InternalCollectionView {
//     func customMenu(for event: NSEvent) -> NSMenu? {
//         guard let contextMenuItemsGenerator = contextMenuItemsGenerator else {
//             return nil
//         }
//
//         // Pass the clicked item's path to the helper.
//         // TODO: include already-selected items (only if the clicked item is selected?)
//         // https://stackoverflow.com/questions/26130872/how-to-implement-contextual-menu-for-nscollectionview
//         let mousePos = convert(event.locationInWindow, from: nil)
//         let clickedItemPath = indexPathForItem(at: mousePos)
//         let itemArray = (clickedItemPath == nil)
//             ? []
//             : [clickedItemPath!]
//
//         if (currentContextMenuItemProxies.count > 0) {
//             print("Replacing previous context menu")
//         }
//         currentContextMenuItemProxies = contextMenuItemsGenerator(itemArray)
//         if currentContextMenuItemProxies.count == 0 {
//             return nil
//         }
//
//         let menu = NSMenu()
//         // TODO: key equivalent should be delete or option delete
//         // https://stackoverflow.com/questions/10327148/cocoa-menu-bar-item-with-backspace-as-key-equivalent
//         for menuItem in currentContextMenuItemProxies {
//             let nsMenuItem = menuItem.createMenuItem()
//             menu.items.append(nsMenuItem)
//         }
//         return menu
//     }
//
//     override func menu(for event: NSEvent) -> NSMenu? {
//         let menu = customMenu(for: event)
//
//         if (menu != nil) {
//             return menu
//         } else {
//             return super.menu(for: event)
//         }
//     }
// }

final class CenteredFlowLayout: NSCollectionViewFlowLayout {
    var itemWidth: CGFloat = 0
    var itemHeight: CGFloat = 0
    
    // Initialize with optional itemWidth and itemHeight for flexibility
    init(itemWidth: CGFloat? = nil, itemHeight: CGFloat? = nil) {
        super.init()
        
        // Set default item size if not provided
        let defaultItemSize = CGSize(width: 50, height: 50) // Default size, adjust as needed
        
        // Apply provided itemWidth and itemHeight, fall back to defaults if nil
        self.itemSize = CGSize(width: itemWidth ?? defaultItemSize.width, height: itemHeight ?? defaultItemSize.height)
        self.itemWidth = itemSize.width
        self.itemHeight = itemSize.height
        
        // Ensure vertical scrolling
        self.scrollDirection = .vertical
        
        sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        // Additional configuration here if needed
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        let superAttributes = super.layoutAttributesForElements(in: rect)
        guard let collectionView = self.collectionView else { return superAttributes }
        
        // Copy items to avoid altering original attributes from super
        let attributes = superAttributes.map { $0.copy() as! NSCollectionViewLayoutAttributes }
        
        // Dictionary to keep track of the last max Y for each row
        var lastMaxYByRow = [Int: CGFloat]()
        
        // Iterate over the attributes to adjust each item's frame to be centered
        attributes.forEach { layoutAttribute in
            // Determine the row based on the item's frame
            let row = Int(layoutAttribute.frame.origin.y / (layoutAttribute.frame.size.height + self.minimumLineSpacing))
            let maxY = lastMaxYByRow[row] ?? 0
            
            if layoutAttribute.frame.origin.y >= maxY {
                // Calculate total row width
                let rowAttributes = attributes.filter {
                    Int($0.frame.origin.y / ($0.frame.size.height + self.minimumLineSpacing)) == row
                }
                let rowWidth = rowAttributes.reduce(0) { $0 + $1.frame.width } + CGFloat(rowAttributes.count - 1) * self.minimumInteritemSpacing
                let leftPadding = (collectionView.bounds.width - rowWidth) / 2.0
                
                // Adjust each item's origin.x based on the calculated leftPadding
                var xOffset = leftPadding
                rowAttributes.forEach { attr in
                    attr.frame.origin.x = xOffset
                    xOffset += attr.frame.width + self.minimumInteritemSpacing
                }
                
                // Update the last max Y for the row
                lastMaxYByRow[row] = layoutAttribute.frame.maxY
            }
        }
        return attributes
    }
}

// NSObject is necessary to implement NSCollectionViewDataSource
// TODO: ItemType extends identifiable?
// TODO: Move the delegates to a coordinator.
public struct CollectionView<ItemType, Content: View>: /* NSObject, */ NSViewRepresentable /* NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout */ where ItemType: Equatable, ItemType: Identifiable  {
    var items: [ItemType]
    @Binding var selection: Set<ItemType.ID>
    var itemWidth: CGFloat?
    var itemHeight: CGFloat?
    var dataChangeNeeds = 0
    
    var iddd = UUID().uuidString
    // TODO: why is this a binding?
//    @Binding var items: [ItemType]

    typealias ItemRenderer = (_ item: ItemType) -> Content
    @ViewBuilder var renderer: ItemRenderer
    
    typealias DragHandler = (_ item: ItemType) -> NSPasteboardWriting?
    private var dragHandler: DragHandler?
    
    typealias QuickLookHandler = (_ items: [ItemType]) -> [URL]?
    private var quickLookHandler: QuickLookHandler?
    
    typealias DeleteItemsHandler = (_ items: [ItemType]) -> Void
    private var deleteItemsHandler: DeleteItemsHandler?
    
    typealias ContextMenuItemsGenerator = (_ items: [ItemType]) -> [NSMenuItemProxy]
    var contextMenuItemsGenerator: ContextMenuItemsGenerator? = nil
    
    private var collection: NSCollectionView? = nil
    
    public init(items: [ItemType], selection: Binding<Set<ItemType.ID>>, itemWidth: CGFloat? = nil, itemHeight: CGFloat? = nil, dataChangeNeeds: Int = 0, @ViewBuilder renderer: @escaping (_ item: ItemType) -> Content) {
        self.itemWidth = itemWidth
        self.itemHeight = itemHeight
        self.items = items
        _selection = selection
        self.dataChangeNeeds = dataChangeNeeds
        self.renderer = renderer
    }
    
    public final class Coordinator: NSObject, NSCollectionViewDelegate, QLPreviewPanelDelegate, QLPreviewPanelDataSource, NSCollectionViewDataSource {
        var parent: CollectionView<ItemType, Content>
        var selection: Binding<Set<ItemType.ID>>
        
        private var previousItems: [ItemType] = []
        private var previousDataChangeNeeds = 0
        
        var didRegisterCells = false
        
        var selectedIndexPaths: Set<IndexPath> = Set<IndexPath>()
        var selectedItems: [ItemType] {
            get {
                var selectedItems: [ItemType] = []
                for index in selectedIndexPaths {
                    selectedItems.append(parent.items[index.item])
                }
                return selectedItems
            }
        }
        
        init(_ parent: CollectionView<ItemType, Content>) {
            self.parent = parent
            self.previousItems = parent.items
            self.previousDataChangeNeeds = parent.dataChangeNeeds
            self.selection = parent.$selection
        }
        
        func itemsDidUpdate(newItems: [ItemType], newDataChangeNeeds: Int) -> Bool {
            defer {
                previousItems = newItems
                previousDataChangeNeeds = newDataChangeNeeds
            }
            return previousDataChangeNeeds != newDataChangeNeeds || previousItems != newItems
        }
        
        // NSCollectionViewDelegate
        // TODO: use Set<IndexPath> version
        public func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt index: Int) -> NSPasteboardWriting? {
            guard let dragHandler = parent.dragHandler else { return nil }
            
            let item = parent.items[index]
            return dragHandler(item)
        }
        
        public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            selection.wrappedValue = Set(collectionView.selectionIndexPaths.compactMap { parent.items[$0.item].id })
 
            // Unsure if necessary to queue:
            DispatchQueue.main.async {
                self.selectedIndexPaths.formUnion(indexPaths)
//                print("Selected items: \(self.selectedIndexPaths) (added \(indexPaths))")
                
                if let quickLook = QLPreviewPanel.shared() {
                    if (quickLook.isVisible) {
                        quickLook.reloadData()
                    }
                }
            }
        }
        
        public func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            selection.wrappedValue = Set(collectionView.selectionIndexPaths.compactMap { parent.items[$0.item].id })
            
            // Unsure if necessary to queue:
            DispatchQueue.main.async {
                self.selectedIndexPaths.subtract(indexPaths)
//                print("Selected items: \(self.selectedIndexPaths) (removed \(indexPaths))")
                
                if let quickLook = QLPreviewPanel.shared() {
                    if (quickLook.isVisible) {
                        quickLook.reloadData()
                    }
                }
            }
        }
        
        public func collectionView(_ collectionView: NSCollectionView, didEndDisplaying item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
            // Unsure if necessary to queue:
            DispatchQueue.main.async {
                // TODO: this fires too much (like when we resize the view). I think that matches actual selection behavior, but I'd like to do better.
                self.selectedIndexPaths.subtract([indexPath])
//                print("Selected items: \(self.selectedIndexPaths) (removed \(indexPath) because item removed)")
            }
        }
        
        private func isQuickLookEnabled() -> Bool {
            return parent.quickLookHandler != nil
        }
        
        private func isDeleteItemsEnabled() -> Bool {
            return parent.deleteItemsHandler != nil
        }
        
        func handleKeyDown(_ event: NSEvent) -> Bool {
            let spaceKeyCode: UInt16 = 49
            let deleteKeyCode: UInt16 = 51
            switch event {
            case _ where event.keyCode == spaceKeyCode:
                guard isQuickLookEnabled() else {
                    return false
                }
                
                print("Space pressed & QuickLook is enabled.")
                if let quickLook = QLPreviewPanel.shared() {
                    let isQuickLookShowing = QLPreviewPanel.sharedPreviewPanelExists() && quickLook.isVisible
                    if (isQuickLookShowing) {
                        quickLook.reloadData()
                    } else {
                        quickLook.dataSource = self
                        quickLook.delegate = self
                        quickLook.center()
                        quickLook.makeKeyAndOrderFront(nil)
                    }
                }
                
                return true
            case _ where event.keyCode == deleteKeyCode && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command:
                guard isDeleteItemsEnabled() else {
                    return false
                }
                
                if let deleteItemsHandler = parent.deleteItemsHandler {
                    deleteItemsHandler(selectedItems)
                }
                return true
            default:
                return false
            }
        }
        
        // QLPreviewPanelDelegate
        // Inspired by https://stackoverflow.com/a/33923618/788168
        public func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
            if (event.type == .keyDown) {
                print("Key down: \(event.keyCode); modifiders: \(event.modifierFlags)")
                
                // TODO: forward Option+Backspace to the NSCollectionView?
                let upArrow: UInt16 = 126
                let rightArrow: UInt16 = 124
                let downArrow: UInt16 = 125
                let leftArrow: UInt16 = 123
                switch event.keyCode {
                case upArrow: fallthrough
                case rightArrow: fallthrough
                case downArrow: fallthrough
                case leftArrow:
                    if (event.modifierFlags.contains(.shift)) {
                        // Don't pass through shift-selection keys.
                        return false
                    }
                    // Though I believe the event is handled by QL when
                    // multiple items exist, just be safe.
                    if (selectedIndexPaths.count <= 1) {
                        // Forward the keydown event to the NSCollectionView, which will handle moving focus.
                        parent.collection?.keyDown(with: event)
                        return true
                    }
                default: break
                    // no-op
                }
            }
            
            return false
        }
        
        // QLPreviewPanelDataSource
        public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
            guard isQuickLookEnabled() else {
                return 0
            }
            
            return selectedIndexPaths.count
        }
        
        public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
            guard isQuickLookEnabled() else {
                return nil
            }
            
            guard let quickLookHandler = parent.quickLookHandler, let urls = quickLookHandler(selectedItems) else {
                // If no URLs, return.
                return nil
            }
            
            return urls[index] as QLPreviewItem?
        }
        
        func handleContextMenu(_ items: [IndexPath]) -> [NSMenuItemProxy] {
            guard let generator = parent.contextMenuItemsGenerator else {
                fatalError("Context menu generator should not be called if there is no generator")
            }
            
            let mappedItems = items.map { parent.getItem(for: $0) }
            
            let menuItems = generator(mappedItems)
            return menuItems
        }
        
        // NSCollectionViewDataSource
        public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            // Assume collectionView is the current collectionView.
            return parent.items.count
        }
        
        public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            // Assume collectionView is the current collectionView.
            let cell = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), for: indexPath) as! Cell<Content>
            let currentItem = parent.getItem(for: indexPath)
            
            // cell.representedObject = currentItem
            // print(cell.identifier)
            
            // print("Getting representation \(currentItem)")
            
            // cell.view = self.renderer(currentItem)
            for view in cell.container.views {
                cell.container.removeView(view)
            }
            
            let hostedView = NSHostingView<Content>(rootView:parent.renderer(currentItem))
            cell.contents = hostedView
            cell.container.addView(cell.contents!, in: .center)
            // print(cell.container.frame)
            // // hostedView.frame = cell.container.frame
            //
            // if (cell.contents == nil) {
            //     cell.contents = hostedView
            //     cell.container.addView(cell.contents!, in: .center)
            //     // cell.container.frame = NSRect(origin: cell.container.frame.origin, size: NSSize(width: 50, height: 50))
            // }
            //
            // cell.contents?.frame = cell.container.frame
            // // cell.label.isSelectable = false
            
            return cell
        }
        
        // NSCollectionViewDelegateFlowLayout
        // func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        //     print("Sizing")
        //     return NSSize(
        //         width: itemWidth ?? 400,
        //         height: itemWidth ?? 400
        //     )
        // }
    } // Coordinator
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public typealias NSViewType = NSScrollView
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = InternalCollectionView()
        scrollView.documentView = collectionView
        
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true

        updateNSView(scrollView, context: context)
        
        return scrollView
    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let collectionView = scrollView.documentView as! InternalCollectionView
        // self.collection = collectionView
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        
        if context.coordinator.itemsDidUpdate(newItems: items, newDataChangeNeeds: dataChangeNeeds) {
            let selections = collectionView.selectionIndexes
            collectionView.reloadData()
            collectionView.selectionIndexes = selections
        }
        
        // Drag and drop
        // https://www.raywenderlich.com/1047-advanced-collection-views-in-os-x-tutorial#toc-anchor-011
        if (dragHandler != nil) {
            collectionView.setDraggingSourceOperationMask(.copy, forLocal: false)
        }
        
        collectionView.keyDownHandler = context.coordinator.handleKeyDown(_:)
        
        if (contextMenuItemsGenerator == nil) {
            collectionView.contextMenuItemsGenerator = nil
        } else {
            collectionView.contextMenuItemsGenerator = context.coordinator.handleContextMenu
        }
        
        // let layout = NSCollectionViewFlowLayout()
        // layout.minimumLineSpacing = 200
        // layout.scrollDirection = .vertical
        // // layout.itemSize = NSSize(width: 1000, height: 300)
        // collectionView.collectionViewLayout = layout
        
//        let widthDimension = (itemWidth == nil)
//        ? NSCollectionLayoutDimension.fractionalWidth(1.0)
//        : NSCollectionLayoutDimension.absolute(CGFloat(self.itemWidth!))
//        let itemSize = NSCollectionLayoutSize(widthDimension: widthDimension, heightDimension: .fractionalHeight(1.0))
//        let item = NSCollectionLayoutItem(layoutSize: itemSize)
//        
//        let heightDimension = (itemWidth == nil)
//        ? NSCollectionLayoutDimension.fractionalHeight(1.0)
//        : NSCollectionLayoutDimension.absolute(CGFloat(self.itemWidth!))
//        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: heightDimension)
//        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
//        
//        let section = NSCollectionLayoutSection(group: group)
//        
//        let configuration = NSCollectionViewCompositionalLayoutConfiguration()
//        configuration.scrollDirection = .vertical
//        
//        let layout = NSCollectionViewCompositionalLayout(section: section, configuration: configuration)
//        collectionView.collectionViewLayout = layout
        if (collectionView.collectionViewLayout as? CenteredFlowLayout)?.itemWidth != itemWidth || (collectionView.collectionViewLayout as? CenteredFlowLayout)?.itemHeight != itemHeight {
            let layout = CenteredFlowLayout(itemWidth: itemWidth, itemHeight: itemHeight)
            layout.minimumLineSpacing = 8
            layout.minimumInteritemSpacing = 8
            collectionView.collectionViewLayout = layout
        }
        
        if !context.coordinator.didRegisterCells {
            collectionView.register(Cell<Content>.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("Cell"))
            context.coordinator.didRegisterCells = true
        }
        
        let indexPathsToSelect = items.enumerated().compactMap { index, item -> IndexPath? in
            selection.contains(item.id) ? IndexPath(item: index, section: 0) : nil
        }
        let selectedIndexPaths = Set(collectionView.selectionIndexPaths)
        let indexPathsToDeselect = selectedIndexPaths.subtracting(indexPathsToSelect)
        indexPathsToDeselect.forEach { collectionView.deselectItems(at: [$0]) }
        indexPathsToSelect.forEach { collectionView.selectItems(at: [$0], scrollPosition: .nearestHorizontalEdge) }

//        collectionView.frame = CGRect(x: 0, y: 0, width: 400, height: 100)
//        print(collectionView.frame)
        // TODO: ???
        // layout.itemSize = NSSize(width: 100, height: 100)
//        collectionView.frame = CGRect(x: 0, y: 0, width: 400, height: 100)
        
        collectionView.setNeedsDisplay(collectionView.frame)
    }
    
    private func getItem(for indexPath: IndexPath) -> ItemType {
        return items[indexPath.item]
    }
}

extension CollectionView {
    // Just do lots of copies?
    // https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-modifiers-for-a-uiviewrepresentable-struct
    func onDrag(_ dragHandler: @escaping DragHandler) -> CollectionView {
        var view = self
        view.dragHandler = dragHandler
        return view
    }
}

extension CollectionView {
    func onQuickLook(_ quickLookHandler: @escaping QuickLookHandler) -> CollectionView {
        var view = self
        view.quickLookHandler = quickLookHandler
        return view
    }
}

extension CollectionView {
    func onDeleteItems(_ deleteItemsHandler: @escaping DeleteItemsHandler) -> CollectionView {
        var view = self
        view.deleteItemsHandler = deleteItemsHandler
        return view
    }
}

extension CollectionView {
    func itemContextMenu(_ contextMenuItemGenerator: ContextMenuItemsGenerator?) -> CollectionView {
        var view = self
        view.contextMenuItemsGenerator = contextMenuItemGenerator
        return view
    }
}

//struct CollectionView_Previews: PreviewProvider {
//    static var previews: some View {
////        CollectionView(items: Binding.constant(["a", "b"])) { item in
//        CollectionView(items: ["a", "b"]) { item in
//            Text(item)
//        }
//        .frame(width: 100, height: 100, alignment: .center)
//    }
//}
#endif
