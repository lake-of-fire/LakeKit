import SwiftUI
import SplitView

    
fileprivate struct SplitInternalView<Primary: View, Secondary: View>: View {
    @ObservedObject var splitViewModel: SplitViewModel
    private let primary: Primary
    private let secondary: Secondary
    
    private var prioritySide: SplitSide {
        switch splitViewModel.assistantSide {
        case .primary:
            return .secondary
        case .secondary:
            return .primary
        default: return .primary
        }
    }
    
    private var hideSplitter: Bool {
#if os(macOS)
        return true
#elseif os(iOS)
        return false
#endif
    }
    
    var body: some View {
        Split {
            primary
        } secondary: {
            secondary
        }
        .constraints(priority: prioritySide)
        .constraints(minPFraction: 0.2, minSFraction: 0.2)
        .fraction(splitViewModel.assistantFraction)
        .layout(splitViewModel.assistantLayout)
        .splitter {
            SplitViewSplitter(styling: SplitStyling(
                visibleThickness: 30,
                invisibleThickness: 0,
                hideSplitter: hideSplitter))
        }
    }
    
    fileprivate init(splitViewModel: SplitViewModel, @ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.splitViewModel = splitViewModel
        self.primary = primary()
        self.secondary = secondary()
    }
}

public struct SplitAssistantView<Primary: View, Secondary: View>: View {
    private let assistantSide: SplitSide
    private let defaultAssistantFraction: CGFloat
    private let primary: Primary
    private let secondary: Secondary
    
    @State var splitViewModel: SplitViewModel?
    
    public var body: some View {
        GeometryReader { geometry in
            if let splitViewModel = splitViewModel {
                Group {
                    if #available(iOS 16, macOS 13, *) {
                        let dividerLayout = splitViewModel.assistantLayout.isHorizontal ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
                        SplitInternalView(splitViewModel: splitViewModel) {
                            dividerLayout {
                                primary
                                if splitViewModel.assistantSide == .secondary {
                                    Divider()
                                }
                            }
                        } secondary: {
                            dividerLayout {
                                if splitViewModel.assistantSide == .primary {
                                    Divider()
                                }
                                secondary
                            }
                        }
                    } else {
                        SplitInternalView(splitViewModel: splitViewModel) {
                            primary
                        } secondary: {
                            secondary
                        }
                    }
                }
                //            .hide(splitViewModel.assistantHide)
                .onChange(of: geometry.size) { size in
                    Task { @MainActor in
                        splitViewModel.refreshLayout(geometrySize: geometry.size)
                    }
                }
                .task { @MainActor in
//                    splitViewModel.assistantFraction.value = defaultAssistantFraction
//                    splitViewModel.assistantSide = assistantSide
                    splitViewModel.refreshLayout(geometrySize: geometry.size)
//                    splitViewModel.refresh()
//                    splitViewModel.objectWillChange.send()
                }
            }
        }
        .task { @MainActor in
            splitViewModel = SplitViewModel(assistantSide: assistantSide, assistantFraction: defaultAssistantFraction)
        }
    }
    
    public init(assistantSide: SplitSide, defaultAssistantFraction: CGFloat = 0.5, @ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.assistantSide = assistantSide
        self.defaultAssistantFraction = defaultAssistantFraction
        self.primary = primary()
        self.secondary = secondary()
    }
}

/// The Splitter that separates the `primary` from `secondary` views in a `Split` view.
///
/// The Splitter holds onto `styling`, which is accessed by Split to determine the `visibleThickness` by which
/// the `primary` and `secondary` views are separated. The `styling` also publishes `previewHide`, which
/// specifies whether we are previewing what Split will look like when we hide a side. The Splitter uses `previewHide`
/// to change its `dividerColor` to `.clear` when being previewed, while Split uses it to determine whether the
/// spacing between views should be `visibleThickness` or zero.
@MainActor
struct SplitViewSplitter: SplitDivider {
    @EnvironmentObject private var layout: LayoutHolder
    @ObservedObject public var styling: SplitStyling
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var color: Color {
        if colorScheme == .dark {
            return .secondary.opacity(0.7)
        }
        return .secondary.opacity(0.5)
    }
    private var visibleThickness: CGFloat { privateVisibleThickness ?? styling.visibleThickness }
    private var invisibleThickness: CGFloat { privateInvisibleThickness ?? styling.invisibleThickness }
    private let privateVisibleThickness: CGFloat?
    private let privateInvisibleThickness: CGFloat?
    
    private var visibleColor: Color {
        if styling.previewHide && styling.hideSplitter {
            return .clear
        }
        return color
    }
    
    public var body: some View {
        ZStack {
            switch layout.value {
            case .horizontal:
                Color(white: 1, opacity: 0.0000000001)
                    .frame(width: visibleThickness)
                if !styling.hideSplitter {
                    Capsule()
                        .fill(visibleColor)
                    // Source on 35: https://stackoverflow.com/a/72246733/89373
                        .frame(width: 5, height: 30)
                }
            case .vertical:
                Color(white: 1, opacity: 0.0000000001)
                    .frame(height: visibleThickness)
                if !styling.hideSplitter {
                    Capsule()
                        .fill(visibleColor)
                        .frame(width: 30, height: 5)
                }
            }
        }
        // Perhaps should consider some kind of custom hoverEffect, since the cursor change
        // on hover doesn't work on iOS.
        .onHover { inside in
#if targetEnvironment(macCatalyst) || os(macOS)
            // With nested split views, it's possible to transition from one Splitter to another,
            // so we always need to pop the current cursor (a no-op when it's the only one). We
            // may or may not push the hover cursor depending on whether it's inside or not.
            NSCursor.pop()
            if inside {
                layout.isHorizontal ? NSCursor.resizeLeftRight.push() : NSCursor.resizeUpDown.push()
            }
#endif
        }
    }
    
    public init(visibleThickness: CGFloat? = nil, invisibleThickness: CGFloat? = nil) {
        privateVisibleThickness = visibleThickness
        privateInvisibleThickness = invisibleThickness
        styling = SplitStyling(visibleThickness: visibleThickness, invisibleThickness: invisibleThickness)
    }
    
    public init(styling: SplitStyling) {
        privateVisibleThickness = styling.visibleThickness
        privateInvisibleThickness = styling.invisibleThickness
        self.styling = styling
    }
}
