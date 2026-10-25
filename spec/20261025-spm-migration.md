# Migrate dependencies from CocoaPods to Swift Package Manager

## Summary

Remove CocoaPods from the project entirely. Of the four current pods:

| Pod | Action |
|---|---|
| AppCenter 4.4.2 | Removed, along with all analytics/crash-reporting code |
| Sparkle 1.27.1 | Upgraded to Sparkle 2.x, consumed as a remote SPM package |
| ReactiveObjC 3.1.0 | Vendored into the repo as a local SPM package |
| LookinShared 1.2.7 | Vendored into the repo as a local SPM package |

After this change the project builds from `SupaLookin.xcodeproj` with only Xcode installed — no `pod install`, no `.xcworkspace`.

This is groundwork for the Swift rewrite (`20261025-swift-rewrite.md`) and the MCP server. Both consume packages through SPM: `Packages/LookinShared` and Sparkle here, and the MCP swift-sdk and FlyingFox later.

## Why

- **AppCenter:** Visual Studio App Center was retired on 2025-03-31; its Analytics and Diagnostics services were kept alive only until 2026-06-30. The SDK has nowhere to send data. It's also already inert in SupaLookin: `AppDelegate.resolveAppCenterKey` only returns a key for the upstream bundle ID `hughkli.Lookin`, so under `icu.retrouvailles.supalookin` it asserts in Debug and leaves AppCenter disabled.
- **Sparkle:** SPM is only supported by Sparkle 2. Sparkle 1 is legacy.
- **ReactiveObjC:** no SPM manifest upstream; last release 2019. It's used throughout the client (`RACSignal`, `RACObserve`, `@weakify`, ...), so replacing it is not in scope — vendoring keeps it working unchanged.
- **LookinShared:** upstream `QMUI/LookinServer` has been inactive since 2024-07. Its `Package.swift` only declares iOS/tvOS and only exposes the iOS-side `LookinServer` product, so there's no SPM product the macOS client can consume. SupaLookin develops independently, so it owns its copy of the shared protocol files from here on.

## Package layout

```
Packages/
  LookinShared/
    Package.swift
    LICENSE                 (upstream LookinServer LICENSE, unchanged)
    UPSTREAM.md             (source repo URL + commit)
    Sources/LookinShared/
      include/              (every upstream .h, flattened, plus the LookinShared.h umbrella)
      *.m                   (every upstream .m, flattened)
  ReactiveObjC/
    Package.swift
    LICENSE.md              (upstream LICENSE.md, unchanged)
    UPSTREAM.md
    Sources/ReactiveObjC/
      include/ReactiveObjC/         (public headers)
      PrivateHeaders/ReactiveObjC/  (private headers)
      *.m                           (every .m, extobjc/ included, flattened)
```

Both are added to the Xcode project as local packages and linked into the `SupaLookin` target. Both manifests declare `.macOS(.v14)` to match the app's deployment target.

### LookinShared

- Source: `https://github.com/QMUI/LookinServer.git` at commit `985e8afe77aa2f3fab599da4f9882f6e43eed919` — the commit `Podfile.lock` resolved `develop` to. `UPSTREAM.md` records the URL and commit.
- The files of upstream `Src/Main/Shared/` and `Src/Base/` are byte-identical to that commit. Their subdirectories (`Category/`, `Peertalk/`) are flattened, since the sources reference each other only by quoted header name.
- The client's existing quoted imports (`#import "LookinDefines.h"` and the other `Lookin*.h` headers, including those in `LookinClient_PrefixHeader.pch`) keep compiling without being rewritten.
- `SHOULD_COMPILE_LOOKIN_SERVER=1` is defined in the package's `cSettings`, matching the old podspec's `pod_target_xcconfig`. The app target already defines it for its own sources and keeps doing so.
- The sources assume Cocoa is already imported, which CocoaPods' generated prefix header used to provide (e.g. `Image+Lookin.h` imports only Foundation but uses `NSImage`). Two package-owned pieces replace it:
  - The `include/LookinShared.h` umbrella header imports `<Cocoa/Cocoa.h>` and then every other header, the way CocoaPods' generated umbrella did. It's the only file in the package that isn't from upstream.
  - `-include Cocoa/Cocoa.h` is set through `unsafeFlags` for the package's own `.m` files. SwiftPM allows `unsafeFlags` in local packages.

### ReactiveObjC

- Source: `https://github.com/ReactiveCocoa/ReactiveObjC.git` at tag `3.1.0`, the exact version the `Podfile` pinned, so behavior doesn't change.
- The files are exactly what CocoaPods built from that tag for macOS:
  - the podspec's `prepare_command` applied: the `extobjc` `EXT*` / `metamacros` files renamed with a `RAC` prefix, and their imports rewritten to match
  - its `osx.exclude_files` removed: the UIKit and MapKit categories
- Header layout:
  - Public headers sit under `include/ReactiveObjC/`, so the existing `#import <ReactiveObjC/ReactiveObjC.h>` in the prefix header, and the umbrella's own `<ReactiveObjC/...>` imports, resolve unchanged.
  - `PrivateHeaders/ReactiveObjC/` holds the podspec's `private_header_files`, plus the internal headers `ReactiveObjC.h` doesn't import, which would otherwise trigger `-Wincomplete-umbrella`.
- SPM doesn't compile DTrace provider files. `RACCompoundDisposableProvider.d` and `RACSignalProvider.d` are replaced by their generated headers (`dtrace -h -s <file>.d -o <file>.h`), committed alongside the sources.
- `UPSTREAM.md` records all of the above.

## Sparkle 2

- Added as a remote package: `https://github.com/sparkle-project/Sparkle`, version rule "Up to Next Major" from `2.10.0`. `Package.resolved` is committed.
- `SUUpdater` is replaced by a single `SPUStandardUpdaterController` created in code at launch (started immediately). The `SUUpdater` custom object is removed from `MainMenu.xib`, and `LKAppMenuManager._handleCheckUpdates` calls `checkForUpdates:` on that controller.
- Info.plist keys stay as they are: `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks` are all read by Sparkle 2 the same way. The app already uses an EdDSA public key, which Sparkle 2 requires.
- Sparkle 2 is still an embedded dynamic framework, so the existing `com.apple.security.cs.disable-library-validation` entitlement (see `20260925-release-workflow.md`) stays.

## AppCenter removal

Everything that exists only to feed AppCenter goes away:

- `@import AppCenter` / `AppCenterAnalytics` / `AppCenterCrashes`, `MSACAppCenter start:` and `resolveAppCenterKey` in `AppDelegate.m`.
- Every `MSACAnalytics trackEvent:` call, plus any state that exists solely to build or gate an event: the `hasCustomSubviews` / `hasCustomAttrs` flags in `LKHierarchyDataSource`, and `isUsingDanceUI` in `LKStaticHierarchyDataSource`.
- `LKPerformanceReporter` (it only times reloads to send `Perf(...)` events) and its call sites in `LKLaunchViewController`, `LKStaticWindowController` and `LKStaticAsyncUpdateManager`.
- `LKPreferenceManager`: the `enableReport` property, its key, setter, `reportStatistics`, and the `reportStatistics` call in `LKStaticViewController`.
- Preferences UI: the "Share analytics with Lookin" switch, its layout, and its line in "Reset", plus both of its strings in `en.lproj` and `zh-Hans.lproj` `Localizable.strings`.

The `enableReport` value already stored in existing users' `NSUserDefaults` is left alone; nothing reads it anymore.

## Project & build changes

- Delete `Podfile`, `Podfile.lock` and `SupaLookin.xcworkspace`. In `.gitignore`, drop the `Pods/` and workspace `xcuserdata` entries and ignore SwiftPM's `.build/` and `.swiftpm/`.
- Remove all CocoaPods integration from `SupaLookin.xcodeproj`:
  - the `Pods_SupaLookin.framework` link
  - the `[CP] Check Pods Manifest.lock` and `[CP] Embed Pods Frameworks` build phases
  - the `Pods-*.xcconfig` base configurations and the `Pods` group
  - the `COCOAPODS=1` preprocessor definition
- `AGENTS.md`'s project context describes the SPM setup instead of CocoaPods.
- The release workflow (`.github/workflows/release.yml`) drops the `pod install --repo-update` step and builds with `-project SupaLookin.xcodeproj` instead of `-workspace SupaLookin.xcworkspace`; `xcodebuild` resolves the SPM packages itself. An update section is appended to `20260925-release-workflow.md` recording this.

## LookinServer protocol compatibility

The vendored `LookinShared` is the client's copy of the wire protocol. This migration doesn't change any of its contents, so compatibility with existing LookinServer integrations (USB/Peertalk framing, `LookinRequestType` values, `NSSecureCoding` keys, `LOOKIN_SERVER_VERSION` / `LOOKIN_SUPPORTED_SERVER_MIN` / `MAX`) is unaffected.

Future edits to the vendored copy have to stay wire-compatible: adding request types or fields is fine; renumbering, renaming coding keys, or changing the meaning of existing ones is not.

## Verification

- A fresh clone, on a machine without CocoaPods, builds in Release with the workflow's ad-hoc overrides (`CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`), and the resulting app launches.
- Connected to an iOS app running stock LookinServer: the hierarchy loads, screenshots render, an inbuilt attribute modification applies, and a console method invocation returns.
- "Check for Updates" opens Sparkle 2's UI without errors.
- The Preferences window no longer shows the analytics switch.
- No remaining references to `AppCenter`, `MSAC`, `SUUpdater`, `Pods` or `xcworkspace` in the project, sources, or workflow (`grep`).
- `Packages/LookinShared/Sources` matches upstream commit `985e8af` file-for-file, apart from the added umbrella header. `Packages/ReactiveObjC/Sources` matches the former `Pods/ReactiveObjC` file-for-file, apart from the two DTrace headers that replace the `.d` files.

## Out of scope

- `SUFeedURL` still points at upstream's `https://lookin.work/release/appcast.xml`, and `SUPublicEDKey` is upstream's key. Moving updates to a SupaLookin-owned appcast and key is a separate spec.
- Replacing ReactiveObjC, or any other refactor of the vendored code.
- Adding a replacement crash-reporting or analytics service.
- Any LookinShared protocol changes, and the MCP server itself.
