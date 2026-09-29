# Swift 6 onboarding qualification for Reader-main tuple

Lake #59 exposed two compile failures in Reader main's exact LakeKit selection when building LakeOfFireReader with Swift 6.2+:

- `OnboardingGrainOverlay.makeGrainImage` contained one expression complex enough to exceed the compiler's type-checking budget.
- two onboarding `.task { @MainActor in ... }` closures failed conversion to SwiftUI's sendable async task action.

This port makes no onboarding behavior change:
- the deterministic grain calculation is split into named intermediate values;
- product loading moves into small `@MainActor` async helpers;
- the SwiftUI task closures simply await those helpers.

The workflow reproduces the relevant Reader sibling tuple:
- BigSyncKit `e31100998ed6d5c0a515eebc29ddb9acab3090ee`;
- SwiftUtilities `2258e79bf270c384488058915a58d723ddfe7568`;
- SwiftUIWebView `bb4b8d682b2befdf3bcf4285e3dae08771be2679`.

It builds the actual LakeKit target in Debug and Release using an installed Apple Swift 6.2+ toolchain. If green, Lake #59 should rerun with this exact LakeKit head before the root dependency tuple is considered compatible.

No onboarding state key, UI copy, analytics event, subscription behavior, schema, root pin, signing, rollout or CloudKit state changes.
