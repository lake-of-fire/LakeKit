#!/usr/bin/env bash
# Exercise the real Session/credential repository, not an authentication double.
# SwiftUI presentation and unrelated LakeKit packages remain full-host gates.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'The Session component uses Apple SwiftUI and KeychainSwift; macOS required.' >&2
  exit 1
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
finish() {
  local status=$?
  if [[ -n "${SESSION_PORT_EVIDENCE_DIRECTORY:-}" ]]; then
    mkdir -p "$SESSION_PORT_EVIDENCE_DIRECTORY" || status=1
    cp "$work/Package.swift" "$SESSION_PORT_EVIDENCE_DIRECTORY/test-Package.swift" || status=1
    if [[ -f "$work/Package.resolved" ]]; then
      cp "$work/Package.resolved" "$SESSION_PORT_EVIDENCE_DIRECTORY/Package.resolved" || status=1
    fi
    tar -czf "$SESSION_PORT_EVIDENCE_DIRECTORY/executed-source.tar.gz" -C "$work" Sources Tests || status=1
  fi
  rm -rf "$work" || status=1
  exit "$status"
}
trap finish EXIT
mkdir -p "$work/Sources/LakeKit" "$work/Tests/SessionPortTests"
cp "$root/Tools/SessionPortTests/Package.swift" "$work/Package.swift"
# Retain all account state, Session and SessionError definitions unchanged;
# remove only the unrelated trailing authentication View extension and its import.
python3 - "$root" "$work" <<'PY'
from pathlib import Path
import sys
root, work = map(Path, sys.argv[1:])
source = (root / "Sources/LakeKit/Sessions.swift").read_text()
marker = "public extension View {"
assert source.count(marker) == 1, "Session source boundary changed; review extraction"
component = source.split(marker)[0].replace("import BetterSafariView\n", "")
(work / "Sources/LakeKit/Sessions.swift").write_text(component)
PY
for file in SessionCredentialRepository Session+EphemeralTesting; do
  cp "$root/Sources/LakeKit/$file.swift" "$work/Sources/LakeKit/"
done
for file in SessionCredentialPersistenceTests EphemeralSessionPortTests; do
  cp "$root/Tests/LakeKitTests/$file.swift" "$work/Tests/SessionPortTests/"
done
swift test --package-path "$work" "$@"
