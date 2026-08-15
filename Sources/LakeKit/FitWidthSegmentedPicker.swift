import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct FitWidthSegmentedPicker<Selection: Hashable>: View {
    let options: [Selection]
    @Binding var selection: Selection
    let disabledOptions: Set<Selection>
    let accessibilityIdentifier: String?
    let onSelect: ((Selection) -> Void)?
    let onReselect: ((Selection) -> Void)?
    let titleForOption: (Selection) -> String

    public init(
        _ options: [Selection],
        selection: Binding<Selection>,
        disabledOptions: Set<Selection> = [],
        accessibilityIdentifier: String? = nil,
        onSelect: ((Selection) -> Void)? = nil,
        onReselect: ((Selection) -> Void)? = nil,
        titleForOption: @escaping (Selection) -> String = { String(describing: $0) }
    ) {
        self.options = options
        self._selection = selection
        self.disabledOptions = disabledOptions
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onSelect = onSelect
        self.onReselect = onReselect
        self.titleForOption = titleForOption
    }

    public var body: some View {
#if os(iOS)
        FitWidthSegmentedPickerIOS(
            options: options,
            selection: $selection,
            disabledOptions: disabledOptions,
            accessibilityIdentifier: accessibilityIdentifier,
            onSelect: onSelect,
            onReselect: onReselect,
            titleForOption: titleForOption
        )
#elseif os(macOS)
        FitWidthSegmentedPickerMacOS(
            options: options,
            selection: $selection,
            disabledOptions: disabledOptions,
            accessibilityIdentifier: accessibilityIdentifier,
            onSelect: onSelect,
            onReselect: onReselect,
            titleForOption: titleForOption
        )
        .fixedSize(horizontal: true, vertical: false)
#endif
    }
}

public typealias FitWidthSegmenetedPicker<Selection: Hashable> = FitWidthSegmentedPicker<Selection>

enum FitWidthSegmentedPickerInteraction: Equatable {
    case selectionChanged
    case selectionReselected
}

enum FitWidthSegmentedPickerAction<Selection: Hashable>: Equatable {
    case select(Selection)
    case reselect(Selection)
    case ignore
}

private struct FitWidthSegmentedPickerNativePresentation<Selection: Hashable>: Equatable {
    let options: [Selection]
    let titles: [String]
    let disabledOptions: Set<Selection>
    let accessibilityIdentifier: String?
}

func fitWidthSegmentedPickerAction<Selection: Hashable>(
    options: [Selection],
    disabledOptions: Set<Selection>,
    index: Int,
    interaction: FitWidthSegmentedPickerInteraction
) -> FitWidthSegmentedPickerAction<Selection> {
    guard options.indices.contains(index) else { return .ignore }
    let option = options[index]
    guard !disabledOptions.contains(option) else { return .ignore }
    switch interaction {
    case .selectionChanged:
        return .select(option)
    case .selectionReselected:
        return .reselect(option)
    }
}

#if os(iOS)
private struct FitWidthSegmentedPickerIOS<Selection: Hashable>: UIViewRepresentable {
    let options: [Selection]
    @Binding var selection: Selection
    let disabledOptions: Set<Selection>
    let accessibilityIdentifier: String?
    let onSelect: ((Selection) -> Void)?
    let onReselect: ((Selection) -> Void)?
    let titleForOption: (Selection) -> String

    func makeUIView(context: Context) -> UISegmentedControl {
        let segmentedControl = ReselectingSegmentedControl()
        segmentedControl.apportionsSegmentWidthsByContent = true
        segmentedControl.addTarget(context.coordinator, action: #selector(Coordinator.selectionChanged(_:)), for: .valueChanged)
        segmentedControl.onReselectSegment = { index in
            context.coordinator.selectionReselected(index: index)
        }
        return segmentedControl
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        let presentation = FitWidthSegmentedPickerNativePresentation(
            options: options,
            titles: options.map(titleForOption),
            disabledOptions: disabledOptions,
            accessibilityIdentifier: accessibilityIdentifier
        )
        if context.coordinator.presentation != presentation {
            uiView.removeAllSegments()
            for (index, title) in presentation.titles.enumerated() {
                uiView.insertSegment(withTitle: title, at: index, animated: false)
            }
            for (index, option) in options.enumerated() {
                uiView.setEnabled(!disabledOptions.contains(option), forSegmentAt: index)
            }
            uiView.accessibilityIdentifier = accessibilityIdentifier
            context.coordinator.presentation = presentation
        }
        let selectedSegment = options.firstIndex(of: selection) ?? UISegmentedControl.noSegment
        if uiView.selectedSegmentIndex != selectedSegment {
            uiView.selectedSegmentIndex = selectedSegment
        }
        context.coordinator.onSelectionChanged = { index in
            switch fitWidthSegmentedPickerAction(
                options: options,
                disabledOptions: disabledOptions,
                index: index,
                interaction: .selectionChanged
            ) {
            case let .select(selectedOption):
                if let onSelect {
                    onSelect(selectedOption)
                } else {
                    selection = selectedOption
                }
            case .reselect, .ignore:
                return
            }
        }
        context.coordinator.onSelectionReselected = { index in
            guard case let .reselect(selectedOption) = fitWidthSegmentedPickerAction(
                options: options,
                disabledOptions: disabledOptions,
                index: index,
                interaction: .selectionReselected
            ) else { return }
            onReselect?(selectedOption)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onSelectionChanged: ((Int) -> Void)?
        var onSelectionReselected: ((Int) -> Void)?
        var presentation: FitWidthSegmentedPickerNativePresentation<Selection>?

        @objc func selectionChanged(_ sender: UISegmentedControl) {
            selectionChanged(index: sender.selectedSegmentIndex)
        }

        func selectionChanged(index: Int) {
            onSelectionChanged?(index)
        }

        func selectionReselected(index: Int) {
            onSelectionReselected?(index)
        }
    }

    final class ReselectingSegmentedControl: UISegmentedControl {
        var onReselectSegment: ((Int) -> Void)?

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            let previousSelectedSegmentIndex = selectedSegmentIndex
            super.touchesEnded(touches, with: event)
            guard previousSelectedSegmentIndex != UISegmentedControl.noSegment,
                  previousSelectedSegmentIndex == selectedSegmentIndex else {
                return
            }
            onReselectSegment?(selectedSegmentIndex)
        }
    }
}
#elseif os(macOS)
private struct FitWidthSegmentedPickerMacOS<Selection: Hashable>: NSViewRepresentable {
    let options: [Selection]
    @Binding var selection: Selection
    let disabledOptions: Set<Selection>
    let accessibilityIdentifier: String?
    let onSelect: ((Selection) -> Void)?
    let onReselect: ((Selection) -> Void)?
    let titleForOption: (Selection) -> String

    func makeNSView(context: Context) -> NSSegmentedControl {
        let segmentedControl = NSSegmentedControl()
        segmentedControl.segmentStyle = .rounded
        segmentedControl.segmentDistribution = .fillProportionally
        segmentedControl.trackingMode = .selectOne
        segmentedControl.target = context.coordinator
        segmentedControl.action = #selector(Coordinator.selectionChanged(_:))
        return segmentedControl
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        let presentation = FitWidthSegmentedPickerNativePresentation(
            options: options,
            titles: options.map(titleForOption),
            disabledOptions: disabledOptions,
            accessibilityIdentifier: accessibilityIdentifier
        )
        if context.coordinator.presentation != presentation {
            nsView.segmentCount = options.count
            for (index, title) in presentation.titles.enumerated() {
                nsView.setLabel(title, forSegment: index)
                nsView.setWidth(0, forSegment: index)
            }
            for (index, option) in options.enumerated() {
                nsView.setEnabled(!disabledOptions.contains(option), forSegment: index)
            }
            nsView.setAccessibilityIdentifier(accessibilityIdentifier)
            context.coordinator.presentation = presentation
        }
        let selectedSegment = options.firstIndex(of: selection) ?? -1
        if nsView.selectedSegment != selectedSegment {
            nsView.selectedSegment = selectedSegment
        }
        context.coordinator.synchronizeSelection(selectedSegment)
        context.coordinator.onSelectionChanged = { index, isReselection in
            switch fitWidthSegmentedPickerAction(
                options: options,
                disabledOptions: disabledOptions,
                index: index,
                interaction: isReselection ? .selectionReselected : .selectionChanged
            ) {
            case let .reselect(selectedOption):
                onReselect?(selectedOption)
            case let .select(selectedOption):
                if let onSelect {
                    onSelect(selectedOption)
                } else {
                    selection = selectedOption
                }
            case .ignore:
                return
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onSelectionChanged: ((Int, Bool) -> Void)?
        private var selectedSegment = -1
        var presentation: FitWidthSegmentedPickerNativePresentation<Selection>?

        func synchronizeSelection(_ selectedSegment: Int) {
            self.selectedSegment = selectedSegment
        }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            let newSelection = sender.selectedSegment
            let isReselection = newSelection == selectedSegment
            selectedSegment = newSelection
            onSelectionChanged?(newSelection, isReselection)
        }
    }
}
#endif
