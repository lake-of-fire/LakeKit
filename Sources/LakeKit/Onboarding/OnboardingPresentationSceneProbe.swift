#if os(iOS)
import SwiftUI
import UIKit

struct OnboardingPresentationSceneProbe: UIViewRepresentable {
    let observer: (any OnboardingPresentationSceneObserver)?

    func makeUIView(context: Context) -> NativeView {
        let view = NativeView()
        view.updateObserver(observer)
        return view
    }

    func updateUIView(_ uiView: NativeView, context: Context) {
        uiView.updateObserver(observer)
    }

    static func dismantleUIView(_ uiView: NativeView, coordinator: ()) {
        uiView.endObservation()
    }

    final class NativeView: UIView {
        private let owner = UUID()
        private weak var observer: (any OnboardingPresentationSceneObserver)?
        private weak var reportedScene: UIWindowScene?
        private var hasReportedScene = false
        private var hasEndedObservation = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportCurrentScene()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // A window can acquire its scene after this view first enters the window.
            reportCurrentScene()
        }

        func updateObserver(_ observer: (any OnboardingPresentationSceneObserver)?) {
            guard !hasEndedObservation else { return }
            replaceObserver(observer)
            reportCurrentScene()
        }

        func endObservation() {
            guard !hasEndedObservation else { return }
            hasEndedObservation = true
            replaceObserver(nil)
        }

        private func replaceObserver(_ observer: (any OnboardingPresentationSceneObserver)?) {
            guard self.observer !== observer else { return }
            let previousObserver = self.observer
            let hadScene = hasReportedScene
            self.observer = observer
            reportedScene = nil
            hasReportedScene = false
            if hadScene {
                previousObserver?.onboardingPresentation(owner, didMoveTo: nil)
            }
        }

        private func reportCurrentScene() {
            guard !hasEndedObservation, let observer else { return }
            let scene = window?.windowScene
            guard hasReportedScene != (scene != nil) || reportedScene !== scene else { return }
            reportedScene = scene
            hasReportedScene = scene != nil
            observer.onboardingPresentation(owner, didMoveTo: scene)
        }
    }
}
#endif
