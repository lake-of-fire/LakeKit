# LakeKit v3-hotfix/main integration candidate

This branch composes the focused LakeKit porting work into one reviewable main candidate.

Included source PRs:
- #5: isolated/ephemeral session fixtures and tests.
- #6: segmented-picker callbacks, owned share-sheet lifecycle, Transferable/UI tests.
- #7: onboarding accessibility identifiers.
- #8: Swift 6 onboarding compilation fix discovered by Lake #59.

## Conflict handling

#5 and #6 are path-disjoint from onboarding and are copied exactly from their reviewed heads.

#7 and #8 both modify `OnboardingSheet.swift`. The integration keeps #8's Swift 6-safe source and reapplies #7's four accessibility contracts:
- `OnboardingWelcome.GetStartedButton` / `Onboarding.PrimaryButton`;
- two `OnboardingWelcome.SkipButton` surfaces;
- `Onboarding.BackButton`.

The Swift 6 changes preserve behavior:
- deterministic grain math is split into intermediate values;
- asynchronous highlighted-product loading is owned by a `@MainActor` loader;
- the loader stores non-Sendable `StoreHelper` only on the main actor;
- disappearance cancels the owned task and cancelled stale work cannot publish.

No `@unchecked Sendable` conformance or `@preconcurrency` suppression is added for StoreHelper.

## Qualification

The branch retains the workflows from #5, #6 and #8. They must all pass on the exact combined head before this integration is considered ready for a Reader root tuple.

Lake #59 is the downstream compile gate: once this candidate is green, its exact head should replace Reader main's old LakeKit revision in #59 and the actual `LakeOfFireReader` Debug/Release sibling build should rerun.

No app state key, StoreKit behavior, schema, Reader root pin, signing, rollout or CloudKit state changes.
