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

## 2026-10-10 focused forward-port audit

The audit compared committed hotfix `a5db41e0ca326cb0cbe0094dcce9fcdff2160a6b`
with fresh main `ce5732052d1480329b4b1c47f1440877dedf0e41`. No pending
upstream LakeKit PRs were present in the frozen inventory.

Two focused source gaps are adapted in the current candidate:

- `LocationBarProgressBar` now cancels its delayed hide on disappearance and
  uses `LocationBarProgressHide.run`, which checks cancellation before and after
  the sleep on MainActor. A canceled old navigation cannot hide/reset successor
  progress. Provenance: hotfix `356cff225d26620d8d2313106c3229d32a9a6fb5`
  and `b93f882ebc5790a5f713c7c8f7bc1324da443a29`.
- `StoreView.purchaseOptionsGrid` uses the hotfix's ordered `ForEach` candidates
  and narrowly scoped `AnyView` availability boundary to avoid the documented
  Xcode 27 tuple/availability inference failure. Provenance: hotfix
  `211a3b977a0f9977593807f0caae603b9bdfb697` and
  `e5a8226f649a678165316dfef813fa8d0ebdaa5e`. The newer main onboarding loader
  and accessibility identifiers remain intact.

`LocationBarProgressHideTests` belongs to the existing SwiftPM `LakeKitTests`
target and covers suspended cancellation, pre-cancellation, throwing sleep and
ordinary completion. Tests and builds were **not run by request**. The Reader
root's explicit test-source list does not yet include this regression. Current
candidate compilation, test execution, root integration and mounted rapid
navigation/store layout checks remain unverified. Historical qualification above
does not qualify this new candidate.
