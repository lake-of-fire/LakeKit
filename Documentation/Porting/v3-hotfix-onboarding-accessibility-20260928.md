# Porting work: v3-hotfix onboarding accessibility identifiers

Source: LakeKit hotfix-selected `e26d500b7d38ca9329ee49b96cce9fe2c9489713`, OnboardingSheet.swift blob `11d7d41e7aa9ab63acd12e334230ed43deb6560b`.
Destination: LakeKit main `fda9c422a97c70f20edbe0c49dc6d45e237a63c1`, prior blob `50bd496f13257607c7568b101cf8d5cac737ad64`.
Root tracker: https://github.com/aehlke/manabi-reader/pull/189

This narrow forward port restores four UI-automation identifiers from the hotfix while retaining main's newer onboarding implementation:

- full-screen intro primary action: `OnboardingWelcome.GetStartedButton`;
- ordinary onboarding primary action: `Onboarding.PrimaryButton`;
- both visual variants of the intro dismiss button: `OnboardingWelcome.SkipButton`;
- onboarding back button: `Onboarding.BackButton`.

No layout, action, subscription, skip policy, animation, card model, presentation state or navigation logic is copied from the old branch. The identifiers are modifiers on existing controls and do not affect production behavior for non-automation callers.

The remaining inspected LakeKit divergence does not justify duplicate ports: ReferralCode.swift and StoreView.swift are byte-identical; PersistedLRUCacheExports differs only in comments; main's StoreViewModel has the reviewed testable debug-override refactor; BackgroundWorker has a newer main cancellation loop. Existing PRs #5 and #6 separately cover the hotfix session fixture, picker callback and share-presentation lifetime work.

No behavioral XCTest is claimed for an accessibility modifier. Keep draft until the real onboarding UI tests/build consume these identifiers on the supported Apple targets. No package requirements, account/session state, StoreKit behavior, schema, signing or Reader pin changes.
