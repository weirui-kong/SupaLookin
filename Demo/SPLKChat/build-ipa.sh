#!/bin/zsh
#
#  build-ipa.sh
#  SPLKChat
#
#  Created by Weirui Kong on 2026/11/18.
#
# Builds a Debug SPLKChat.ipa signed ad hoc, for TrollStore to install on a jailbroken device.

set -euo pipefail

DEMO="${0:A:h}"
OUT="${1:-$DEMO/DerivedData/SPLKChat.ipa}"
DERIVED="$DEMO/DerivedData"

# Without Xcode's debug dylib, the executable and the framework are the only code to sign.
xcodebuild -quiet -project "$DEMO/SPLKChat.xcodeproj" -scheme SPLKChat -configuration Debug \
    -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO build

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$DERIVED/Build/Products/Debug-iphoneos/SPLKChat.app" "$STAGE/Payload/"
codesign --force --sign - "$STAGE/Payload/SPLKChat.app/Frameworks/SPLKServerDynamic.framework"
codesign --force --sign - "$STAGE/Payload/SPLKChat.app"

mkdir -p "${OUT:h}"
rm -f "$OUT"
(cd "$STAGE" && zip -qry "$OUT" Payload)
echo "$OUT"
