#!/bin/zsh
#
#  build.sh
#  SupaLookin
#
#  Created by Weirui Kong on 2026/11/18.
#
# Builds splkhidd and its rootless package, JailbreakHelper/build/org.supacode.app.lookin.splkhid.deb, and copies it into
# the Mac app's resources.

set -euo pipefail

HERE="${0:A:h}"
OUT="$HERE/build"
STAGE="$OUT/stage"
rm -rf "$OUT"
mkdir -p "$STAGE/DEBIAN" "$STAGE/var/jb/usr/libexec" "$STAGE/var/jb/Library/LaunchDaemons"

xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=15.0 -fobjc-arc -O2 \
    -framework CoreFoundation "$HERE/splkhidd.m" -o "$STAGE/var/jb/usr/libexec/splkhidd"
# Dopamine trusts ad hoc signed binaries under /var/jb; the entitlements open the HID event system.
codesign -f -s - -i org.supacode.app.lookin.splkhid --entitlements "$HERE/splkhidd.entitlements" "$STAGE/var/jb/usr/libexec/splkhidd"

cp "$HERE/org.supacode.app.lookin.splkhid.plist" "$STAGE/var/jb/Library/LaunchDaemons/"
cp "$HERE/control" "$HERE/postinst" "$HERE/prerm" "$STAGE/DEBIAN/"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm" "$STAGE/var/jb/usr/libexec/splkhidd"
chmod 644 "$STAGE/var/jb/Library/LaunchDaemons/org.supacode.app.lookin.splkhid.plist"

# A .deb is an ar archive of debian-binary, control.tar.gz and data.tar.gz, in that order.
cd "$OUT"
print "2.0" > debian-binary
COPYFILE_DISABLE=1 tar --uid 0 --gid 0 --uname root --gname wheel -czf control.tar.gz -C "$STAGE/DEBIAN" .
COPYFILE_DISABLE=1 tar --uid 0 --gid 0 --uname root --gname wheel -czf data.tar.gz -C "$STAGE" --exclude ./DEBIAN .
ar -rcS org.supacode.app.lookin.splkhid.deb debian-binary control.tar.gz data.tar.gz
rm -f debian-binary control.tar.gz data.tar.gz

# Supa Lookin bundles the package, and the repository keeps this copy, so building the Mac app needs no iPhoneOS SDK.
mkdir -p "$HERE/../SupaLookin/Live/Resources"
cp org.supacode.app.lookin.splkhid.deb "$HERE/../SupaLookin/Live/Resources/"
print "$OUT/org.supacode.app.lookin.splkhid.deb"
