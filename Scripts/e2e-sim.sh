#!/bin/zsh
#
#  e2e-sim.sh
#  SupaLookin
#
#  Created by Weirui Kong on 2026/11/10.
#
# Builds the e2e demo against the package, runs it on a simulator and runs SPLKEndToEndTests against it.
# Set SPLK_E2E_UDID to pick the simulator; otherwise the first available iPhone is used.

set -euo pipefail

ROOT="${0:A:h:h}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BUNDLE_ID="icu.retrouvailles.splkdemo"

# xcodebuild picks the Xcode project over the package in the repository root, so build from a folder holding only the package.
mkdir -p "$WORK/package"
ln -s "$ROOT/Package.swift" "$ROOT/Package.resolved" "$ROOT/Sources" "$ROOT/Tests" "$WORK/package/"
(cd "$WORK/package" && xcodebuild -quiet -scheme SPLKServer -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath "$WORK/derived" build)

PRODUCTS="$WORK/derived/Build/Products/Debug-iphonesimulator"
APP="$WORK/SPLKDemo.app"
mkdir -p "$APP"
cp "$ROOT/Scripts/e2e/Info.plist" "$APP/Info.plist"
xcrun -sdk iphonesimulator swiftc -module-name SPLKDemo -target "$(uname -m)-apple-ios15.0-simulator" \
    "$ROOT/Scripts/e2e/SPLKDemoApp.swift" "$PRODUCTS"/*.o -o "$APP/SPLKDemo"
codesign --force --sign - "$APP" >/dev/null

UDID="${SPLK_E2E_UDID:-$(xcrun simctl list devices available -j | python3 -I -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
print(next(d["udid"] for runtime in devices.values() for d in runtime if "iPhone" in d["name"]))
')}"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null

for _ in {1..40}; do
    lsof -nP -iTCP:47264-47269 -sTCP:LISTEN >/dev/null 2>&1 && break
    sleep 0.5
done

# Supa Lookin reconnecting to the demo would replace the tests' sessions.
if pgrep -f "Supa Lookin.app/Contents/MacOS/Supa Lookin" >/dev/null; then
    echo "warning: Supa Lookin is running; quit it, or its sessions will replace the tests' sessions." >&2
fi

cd "$ROOT"
SPLK_E2E=1 SPLK_E2E_UDID="$UDID" swift test --filter SPLKEndToEndTests
