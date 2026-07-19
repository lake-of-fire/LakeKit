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
    let onReselect: ((Selection) -> Void)?
    let titleForOption: (Selection) -> String

    public init(
        _ options: [Selection],
        selection: Binding<Selection>,
        disabledOptions: Set<Selection> = [],
        accessibilityIdentifier: String? = nil,
        onReselect: ((Selection) -> Void)? = nil,
        titleForOption: @escaping (Selection) -> String = { String(describing: $0) }
    ) {
        self.options = options
        self._selection = selection
        self.disabledOptions = disabledOptions
        self.accessibilityIdentifier = accessibilityIdentifier
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
            onReselect: onReselect,
            titleForOption: titleForOption
        )
#elseif os(macOS)
        FitWidthSegmentedPickerMacOS(
            options: options,
            selection: $selection,
            disabledOptions: disabledOptions,
            accessibilityIdentifier: accessibilityIdentifier,
            onReselect: onReselect,
            titleForOption: titleForOption
        )
        .fixedSize(horizontal: true, vertical: false)
#endif
    }
}

public typealias FitWidthSegmenetedPicker<Selection: Hashable> = FitWidthSegmentedPicker<Selection>

#if os(iOS)
private struct FitWidthSegmentedPickerIOS<Selection: Hashable>: UIViewRepresentable {
    let options: [Selection]
    @Binding var selection: Selection
    let disabledOptions: Set<Selection>
    let accessibilityIdentifier: String?
    let onReselect: ((Selection) -> Void)?
    let titleForOption: (Selection) -> String

    func makeUIView(context: Context) -> UISegmentedControl {
        let segmentedControl = ReselectingSegmentedControl()
        segmentedControl.apportionsSegmentWidthsByContent = true
        segmentedControl.addTarget(context.coordinator, action: #selector(Coordinator.selectionChanged(_:)), for: .valueChanged)
        segmentedControl.onReselectSegment = { index in
            context.coordinator.selectionChanged(index: index)
        }
        return segmentedControl
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.numberOfSegments != options.count
            || options.enumerated().contains(where: { index, option in
                uiView.titleForSegment(at: index) != titleForOption(option)
            }) {
            uiView.removeAllSegments()
            for (index, option) in options.enumerated() {
                uiView.insertSegment(withTitle: titleForOption(option), at: index, animated: false)
            }
        }

        for (index, option) in options.enumerated() {
            uiView.setEnabled(!disabledOptions.contains(option), forSegmentAt: index)
        }

        uiView.accessibilityIdentifier = accessibilityIdentifier
        uiView.selectedSegmentIndex = options.firstIndex(of: selection) ?? UISegmentedControl.noSegment
        context.coordinator.onSelectionChanged = { index in
            guard options.indices.contains(index) else { return }
            let selectedOption = options[index]
            guard !disabledOptions.contains(selectedOption) else { return }
            if selectedOption == selection {
                onReselect?(selectedOption)
                return
            }
            selection = selectedOption
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onSelectionChanged: ((Int) -> Void)?

        @objc func selectionChanged(_ sender: UISegmentedControl) {
            selectionChanged(index: sender.selectedSegmentIndex)
        }

        func selectionChanged(index: Int) {
            onSelectionChanged?(index)
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
        nsView.segmentCount = options.count
        for (index, option) in options.enumerated() {
            nsView.setLabel(titleForOption(option), forSegment: index)
            nsView.setEnabled(!disabledOptions.contains(option), forSegment: index)
            nsView.setWidth(0, forSegment: index)
        }

        nsView.setAccessibilityIdentifier(accessibilityIdentifier)
        nsView.selectedSegment = options.firstIndex(of: selection) ?? -1
        context.coordinator.onSelectionChanged = { index in
            guard options.indices.contains(index) else { return }
            let selectedOption = options[index]
            guard !disabledOptions.contains(selectedOption) else { return }
            if selectedOption == selection {
                onReselect?(selectedOption)
                return
            }
            selection = selectedOption
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onSelectionChanged: ((Int) -> Void)?

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            onSelectionChanged?(sender.selectedSegment)
        }
    }
}
#endif
