#if os(iOS)
import SwiftUI
import UIKit

/// Observes the actual window scene hosting an iOS onboarding presentation.
@MainActor
public protocol OnboardingPresentationSceneObserver: AnyObject, Sendable {
    /// A non-nil scene owns a mounted presentation until the same owner reports nil
    /// or moves to another scene. Multiple owners can overlap during teardown.
    func onboardingPresentation(_ owner: UUID, didMoveTo scene: UIWindowScene?)
}

extension EnvironmentValues {
    @Entry var onboardingPresentationSceneObserver: (any OnboardingPresentationSceneObserver)?
}

public extension View {
    /// Supplies a scene observer to an onboarding sheet in this view hierarchy.
    @MainActor
    func onboardingPresentationSceneObserver(
        _ observer: (any OnboardingPresentationSceneObserver)?
    ) -> some View {
        environment(\.onboardingPresentationSceneObserver, observer)
    }
}
#endif
