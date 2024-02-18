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

// NSObject is necessary to implement NSCollectionViewDataSource
// TODO: ItemType extends identifiable?
// TODO: Move the delegates to a coordinator.
struct SwiftNSCollectionView<ItemType, Content: View>: /* NSObject, */ NSViewRepresentable /* NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout */ {
    var itemWidth: Double?
    
    // TODO: why is this a binding?
    @Binding var items: [ItemType]
    
    typealias ItemRenderer = (_ item: ItemType) -> Content
    var renderer: ItemRenderer
    
    typealias DragHandler = (_ item: ItemType) -> NSPasteboardWriting?
    private var dragHandler: DragHandler?
    
    typealias QuickLookHandler = (_ items: [ItemType]) -> [URL]?
    private var quickLookHandler: QuickLookHandler?
    
    typealias DeleteItemsHandler = (_ items: [ItemType]) -> Void
    private var deleteItemsHandler: DeleteItemsHandler?
    
    typealias ContextMenuItemsGenerator = (_ items: [ItemType]) -> [NSMenuItemProxy]
    var contextMenuItemsGenerator: ContextMenuItemsGenerator? = nil
    
    private var collection: NSCollectionView? = nil
    
    init(items: Binding<[ItemType]>, itemSize: Double? = nil, renderer: @escaping (_ item: ItemType) -> Content) {
        self.itemWidth = itemSize
        self._items = items
        self.renderer = renderer
    }
    
    internal final class Coordinator: NSObject, NSCollectionViewDelegate, QLPreviewPanelDelegate, QLPreviewPanelDataSource, NSCollectionViewDataSource {
        var parent: SwiftNSCollectionView<ItemType, Content>
        
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
        
        
        init(_ parent: SwiftNSCollectionView<ItemType, Content>) {
            self.parent = parent
        }
        
        // NSCollectionViewDelegate
        // TODO: use Set<IndexPath> version
        func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt index: Int) -> NSPasteboardWriting? {
            guard let dragHandler = parent.dragHandler else { return nil }
            
            let item = parent.items[index]
            return dragHandler(item)
        }
        
        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            // Unsure if necessary to queue:
            DispatchQueue.main.async {
                self.selectedIndexPaths.formUnion(indexPaths)
                print("Selected items: \(self.selectedIndexPaths) (added \(indexPaths))")
                
                if let quickLook = QLPreviewPanel.shared() {
                    if (quickLook.isVisible) {
                        quickLook.reloadData()
                    }
                }
            }
        }
        
        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            // Unsure if necessary to queue:
            DispatchQueue.main.async {
                self.selectedIndexPaths.subtract(indexPaths)
                print("Selected items: \(self.selectedIndexPaths) (removed \(indexPaths))")
                
                if let quickLook = QLPreviewPanel.shared() {
                    if (quickLook.isVisible) {
                        quickLook.reloadData()
                    }
                }
            }
        }
        
        func collectionView(_ collectionView: NSCollectionView, didEndDisplaying item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
            // Unsure if necessary to queue:
            DispatchQueue.main.async {
                // TODO: this fires too much (like when we resize the view). I think that matches actual selection behavior, but I'd like to do better.
                self.selectedIndexPaths.subtract([indexPath])
                print("Selected items: \(self.selectedIndexPaths) (removed \(indexPath) because item removed)")
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
        func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
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
        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
            guard isQuickLookEnabled() else {
                return 0
            }
            
            return selectedIndexPaths.count
        }
        
        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
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
        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            // Assume collectionView is the current collectionView.
            return parent.items.count
        }
        
        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    typealias NSViewType = NSScrollView
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = InternalCollectionView()
        scrollView.documentView = collectionView
        
        updateNSView(scrollView, context: context)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        print("Update")
        let collectionView = scrollView.documentView as! InternalCollectionView
        // self.collection = collectionView
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        
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
        
        let widthDimension = (itemWidth == nil)
        ? NSCollectionLayoutDimension.fractionalWidth(1.0)
        : NSCollectionLayoutDimension.absolute(CGFloat(self.itemWidth!))
        let itemSize = NSCollectionLayoutSize(widthDimension: widthDimension, heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let heightDimension = (itemWidth == nil)
        ? NSCollectionLayoutDimension.fractionalHeight(1.0)
        : NSCollectionLayoutDimension.absolute(CGFloat(self.itemWidth!))
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: heightDimension)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        
        let configuration = NSCollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        
        let layout = NSCollectionViewCompositionalLayout(section: section, configuration: configuration)
        collectionView.collectionViewLayout = layout
        
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        
        collectionView.register(Cell<Content>.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("Cell"))
        
        collectionView.frame = CGRect(x: 0, y: 0, width: 400, height: 100)
        print(collectionView.frame)
        // TODO: ???
        // layout.itemSize = NSSize(width: 100, height: 100)
        collectionView.frame = CGRect(x: 0, y: 0, width: 400, height: 100)
        
        collectionView.setNeedsDisplay(collectionView.frame)
    }
    
    private func getItem(for indexPath: IndexPath) -> ItemType {
        return items[indexPath.item]
    }
}

extension SwiftNSCollectionView {
    // Just do lots of copies?
    // https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-modifiers-for-a-uiviewrepresentable-struct
    func onDrag(_ dragHandler: @escaping DragHandler) -> SwiftNSCollectionView {
        var view = self
        view.dragHandler = dragHandler
        return view
    }
}

extension SwiftNSCollectionView {
    func onQuickLook(_ quickLookHandler: @escaping QuickLookHandler) -> SwiftNSCollectionView {
        var view = self
        view.quickLookHandler = quickLookHandler
        return view
    }
}

extension SwiftNSCollectionView {
    func onDeleteItems(_ deleteItemsHandler: @escaping DeleteItemsHandler) -> SwiftNSCollectionView {
        var view = self
        view.deleteItemsHandler = deleteItemsHandler
        return view
    }
}

extension SwiftNSCollectionView {
    func itemContextMenu(_ contextMenuItemGenerator: ContextMenuItemsGenerator?) -> SwiftNSCollectionView {
        var view = self
        view.contextMenuItemsGenerator = contextMenuItemGenerator
        return view
    }
}

struct SwiftNSCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftNSCollectionView(items: Binding.constant(["a", "b"])) { item in
            Text(item)
        }
        .frame(width: 100, height: 100, alignment: .center)
    }
}
#endif
