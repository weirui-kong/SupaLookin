#!/bin/zsh
#
#  build-xcframework.sh
#  SupaLookin
#
#  Created by Weirui Kong on 2026/11/18.
#
# Builds SPLKServer.xcframework (iOS devices and the iOS Simulator) from the package's SPLKServerDynamic product and
# writes build/xcframework/SPLKServer.xcframework.zip, then prints its SwiftPM checksum. See
# spec/20261118-xcframework-release.md.

set -euo pipefail

ROOT="${0:A:h:h}"
OUT="$ROOT/build/xcframework"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

VERSION="$(sed -n 's/.*SPLK_SERVER_READABLE_VERSION = @"\([^"]*\)".*/\1/p' "$ROOT/Sources/SPLKServer/include/SPLKDefines.h")"
[[ -n "$VERSION" ]] || { print -u2 "Can't read SPLK_SERVER_READABLE_VERSION."; exit 1 }

# xcodebuild picks the Xcode project over the package in the repository root, so build from a folder holding only the package.
mkdir -p "$WORK/package"
ln -s "$ROOT/Package.swift" "$ROOT/Package.resolved" "$ROOT/Sources" "$ROOT/Tests" "$WORK/package/"

# SPLKServer compiles its server only in Debug.
build() {
    local destination="$1" products="$2"
    (cd "$WORK/package" && xcodebuild -quiet -scheme SPLKServerDynamic -destination "$destination" -configuration Debug \
        -derivedDataPath "$WORK/derived" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build)
    local framework="$WORK/$products/SPLKServer.framework"
    mkdir -p "$WORK/$products"
    cp -R "$WORK/derived/Build/Products/$products/PackageFrameworks/SPLKServerDynamic.framework" "$framework"
    mv "$framework/SPLKServerDynamic" "$framework/SPLKServer"
    install_name_tool -id "@rpath/SPLKServer.framework/SPLKServer" "$framework/SPLKServer"
    rm -rf "$framework/_CodeSignature"
    local plist="$framework/Info.plist"
    plutil -replace CFBundleIdentifier -string "org.supacode.app.lookin.splkserver" "$plist"
    plutil -replace CFBundleName -string "SPLKServer" "$plist"
    plutil -replace CFBundleExecutable -string "SPLKServer" "$plist"
    plutil -replace CFBundleShortVersionString -string "$VERSION" "$plist"
    plutil -replace CFBundleVersion -string "$VERSION" "$plist"
}

build 'generic/platform=iOS' Debug-iphoneos
build 'generic/platform=iOS Simulator' Debug-iphonesimulator

rm -rf "$OUT"
mkdir -p "$OUT"
xcodebuild -quiet -create-xcframework \
    -framework "$WORK/Debug-iphoneos/SPLKServer.framework" \
    -framework "$WORK/Debug-iphonesimulator/SPLKServer.framework" \
    -output "$OUT/SPLKServer.xcframework"
(cd "$OUT" && ditto -c -k --sequesterRsrc --keepParent SPLKServer.xcframework SPLKServer.xcframework.zip)
(cd "$WORK/package" && swift package compute-checksum "$OUT/SPLKServer.xcframework.zip")
