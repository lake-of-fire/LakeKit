#!/usr/bin/env bash
# Compile the complete, actual picker/share implementations without unrelated
# Realm/StoreKit dependencies. This is a component gate, not the full app graph.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Native UI component tests require macOS.' >&2; exit 1; }
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
cleanup() {
  local status=$?
  if [[ -n "${UI_PORT_EVIDENCE_DIRECTORY:-}" ]]; then
    mkdir -p "$UI_PORT_EVIDENCE_DIRECTORY" || status=1
    tar -czf "$UI_PORT_EVIDENCE_DIRECTORY/executed-source.tar.gz" -C "$work" Sources Tests Package.swift || status=1
  fi
  rm -rf "$work"
  exit "$status"
}
trap cleanup EXIT
mkdir -p "$work/Sources/LakeKit" "$work/Tests/LakeKitTests"
cat > "$work/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "LakeKitUIPort", platforms: [.macOS("15.0"), .iOS(.v15)], targets: [
    .target(name: "LakeKit"), .testTarget(name: "LakeKitTests", dependencies: ["LakeKit"])
])
SWIFT
cp "$root/Sources/LakeKit/FitWidthSegmentedPicker.swift" "$work/Sources/LakeKit/"
for name in ShareSheet ShareSheetPresentationState Transferable; do
  cp "$root/Sources/LakeKit/ShareLink/$name.swift" "$work/Sources/LakeKit/"
done
for name in FitWidthSegmentedPickerTests ShareSheetPresentationStateTests LakeKitUIPortNativeTests; do
  cp "$root/Tests/LakeKitTests/$name.swift" "$work/Tests/LakeKitTests/"
done
swift test --package-path "$work" "$@"
# Use the installed Xcode toolchain for the real simulator SDK and record its
# identity separately. This typechecks UIKit paths; it is NOT an iOS UI run.
if [[ -n "${UI_PORT_TYPECHECK_IOS:-}" ]]; then
  xcrun --sdk iphonesimulator swiftc --version
  sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
  xcrun --sdk iphonesimulator swiftc -sdk "$sdk" -target arm64-apple-ios15.0-simulator \
    -swift-version 6 -typecheck "$work"/Sources/LakeKit/*.swift
  echo 'IOS_SIMULATOR_TYPECHECK_PASSED'
fi
