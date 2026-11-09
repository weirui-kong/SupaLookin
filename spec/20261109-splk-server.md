# SPLKServer: an independent iOS-side library and the SPLK prefix

## Summary

SupaLookin stops being a client for stock LookinServer and ships its own iOS-side library, **SPLKServer**, from this repository. Client and server form one product that iterates independently of upstream Lookin:

- Upstream LookinServer (`Src/Main`, `Src/Base`, `Src/Swift`) is imported into the repository at commit `ae396132ce6494477457cf450116dc760518d8ad` and replaces the vendored `Packages/LookinShared`.
- Every `Lookin`, `LKS` and `LK` name prefix, in the server, the shared code and the macOS app alike, becomes `SPLK`.
- The repository root holds the `Package.swift` that iOS apps integrate through Swift Package Manager. SPM is the only supported integration.
- SPLKServer listens on its own ports, so it can run in the same app as stock LookinServer, and Supa Lookin no longer finds stock LookinServer.
- The wire protocol restarts at version 1.

Existing code keeps its language: the Objective-C sources stay Objective-C in Lookin's style, and the macOS app stays Swift. New code is written in Swift where possible.

## Layout

```
Package.swift
Sources/
  LICENSE                  (upstream LookinServer MIT license)
  SPLKServerBase/          upstream Src/Base
    include/
  SPLKServerSwift/         upstream Src/Swift
  SPLKServer/              upstream Src/Main
    include/               every Shared header, flattened, plus the SPLKServer.h umbrella
    Shared/                Shared .m files (Category/, Peertalk/ kept)
    Server/                every Server .h/.m (Category/, Connection/, Connection/RequestHandler/, Others/ kept)
SupaLookin/  SupaLookin.xcodeproj  SupaLookinTests/
```

`Packages/` is deleted.

## Package

- `swift-tools-version:5.9`. Platforms: macOS 14 (the client), iOS 13, tvOS 13, visionOS 1.
- Targets follow upstream's split. An SPM target can't mix Swift and Objective-C, and upstream's Objective-C calls its Swift, which reads the Base classes:
  - `SPLKServerBase` (Objective-C): the ivar-trace model.
  - `SPLKServerSwift` (Swift), depends on `SPLKServerBase`: the Swift ivar tracing.
  - `SPLKServer` (Objective-C), depends on both: the shared protocol models, Peertalk, and the server.
- Products: the library `SPLKServer`, containing the `SPLKServer` target. iOS apps add it; the macOS app links the same product as a local package and `import SPLKServer`.
- The shared code and the server stay in one target, as upstream has them. Shared classes call into the server on iOS (`SPLKHierarchyInfo`, `SPLKAppInfo`, `SPLKDisplayItem`, `SPLKObject`), so splitting them would need a refactor.
- Headers:
  - Shared headers are public: `include/`, with `SPLKServer.h` as the umbrella, which imports every one of them.
  - Server headers are private. The target adds each `Server/` subdirectory as a header search path.
- No `unsafeFlags`: SPM rejects them in remote dependencies. Each source imports what it uses instead of relying on a prefix header.

### Compile gates

Two macros replace `SHOULD_COMPILE_LOOKIN_SERVER` and `SPM_LOOKIN_SERVER_ENABLED`:

| Macro | Gates | Defined for |
|---|---|---|
| `SHOULD_COMPILE_SPLK_SHARED` | Shared and Base files | macOS, always; iOS, tvOS, visionOS and Mac Catalyst in Debug |
| `SHOULD_COMPILE_SPLK_SERVER` | Server files and the Swift target | iOS, tvOS, visionOS and Mac Catalyst in Debug |

The macros are set through `cSettings` / `swiftSettings` with platform and `.debug` conditions. Release builds of an iOS app link SPLKServer as empty modules. SPM can't keep a package out of a Release build the way CocoaPods' `:configurations => ['Debug']` did.

The macOS app passes `-Xcc -DSHOULD_COMPILE_SPLK_SHARED=1` in `OTHER_SWIFT_FLAGS`, so its Swift sees the public headers' declarations. This replaces its `-DSHOULD_COMPILE_LOOKIN_SERVER=1`.

## Renaming

Every name with a `Lookin`, `LKS` or `LK` prefix takes `SPLK` instead, in code, comments, file names and Objective-C category names:

| Before | After |
|---|---|
| `LookinDisplayItem`, `LookinAttr_…`, `LookinErrCode_…` | `SPLKDisplayItem`, `SPLKAttr_…`, `SPLKErrCode_…` |
| `LKS_ConnectionManager`, `LKSConfigManager`, `LKS_Localized` | `SPLKConnectionManager`, `SPLKConfigManager`, `SPLKLocalized` |
| `Lookin_PTChannel` | `SPLK_PTChannel` |
| `LKConnectionManager`, `LookinDocument` (macOS app) | `SPLKConnectionManager`, `SPLKDocument` |
| `LOOKIN_SERVER_VERSION` | `SPLK_SERVER_VERSION` |
| `lookin_bindObject:`, `lks_rgbaComponents` | `splk_bindObject:`, `splk_rgbaComponents` |
| `lookinServerVersion`, `lookinBlack` | `splkServerVersion`, `splkBlack` |
| `UIView (LookinServer)`, `NSArray (Lookin)` | `UIView (SPLKServer)`, `NSArray (SPLK)` |
| `UIView+LookinServer.m`, `Color+Lookin.h`, `LKHelper.swift` | `UIView+SPLKServer.m`, `Color+SPLK.h`, `SPLKHelper.swift` |
| upstream's marker class `Lookin` | `SPLK` |

- A few server and macOS app classes now share a name: `SPLKConnectionManager`, `SPLKExportManager`, `SPLKHelper`. One of each pair is iOS-only Objective-C and the other is the macOS app's Swift, so they never meet in one binary.
- String values that only live in one process take the prefix too: notification names, associated-object keys, log prefixes, temporary file names.
- The product name "Lookin" in prose and user-facing text is not a prefix and stays as it is. So do links to upstream issues and paths in upstream's repositories.
- Unchanged, since they are stored data rather than names:
  - `NSCoder` keys (`lookinServerVersion`, `swiftEnabledInLookinServer`)
  - `UserDefaults` keys and window autosave names in the macOS app (`LKWindowSizeName_Dynamic`, `LKMessageManager_HasReadJobs`, …)

  Keeping the coder keys lets the app still read `.lookin` documents (see Documents), and keeping the defaults keys keeps users' preferences.

### Host app hooks

The selectors and names an iOS app uses to talk to the library are renamed like everything else:

| Before | After |
|---|---|
| `lookin_customDebugInfos`, `lookin_customDebugInfos_<n>` | `splk_customDebugInfos`, `splk_customDebugInfos_<n>` |
| `lookin_collapsedClassList`, `lookin_colorAlias` | `splk_collapsedClassList`, `splk_colorAlias` |
| `lookin_shouldCaptureImage`, `…OfView:`, `…OfLayer:` | `splk_shouldCaptureImage`, `…OfView:`, `…OfLayer:` |
| `lookin_source` (custom attribute dictionary key) | `splk_source` |
| notifications `Lookin_2D`, `Lookin_3D`, `Lookin_Export`, `Lookin_RelationSearch` | `SPLK_2D`, `SPLK_3D`, `SPLK_Export`, `SPLK_RelationSearch` |
| `GetLookinInfo` notification, answered under `lookinServerVersion` | `GetSPLKInfo`, answered under `splkServerVersion` |
| `NSClassFromString(@"Lookin")` | `NSClassFromString(@"SPLK")` |

Apps that implement the `lookin_` hooks for stock LookinServer keep them and add the `splk_` ones for SPLKServer.

### Swift ivar tracing

SPM always builds `SPLKServerSwift`, so `SPLKTraceManager` imports it unconditionally and `SPLKAppInfo` always reports Swift tracing as enabled. The CocoaPods-only branches (`LOOKIN_SERVER_SWIFT_ENABLED`, `<LookinServer/LookinServer-Swift.h>`) are removed.

`SPLKIvarTrace.h` has no compile gate. `SPLKServerSwift` reads it through the Clang importer, which doesn't see the C macros set for `SPLKServerBase`.

## Ports and protocol

| | Stock LookinServer | SPLKServer |
|---|---|---|
| Simulator | 47164–47169 | 47264–47269 |
| USB device | 47175–47179 | 47275–47279 |

- `SPLK_SERVER_VERSION`, `SPLK_CLIENT_VERSION`, `SPLK_SUPPORTED_SERVER_MIN` and `SPLK_SUPPORTED_SERVER_MAX` are all `1`.
- The client drops the checks that only existed for older stock servers:
  - the `-1` / `100` server versions in the ping check
  - the "1.2.7 or higher" gates on reloading an item and its children
- Frame types, request types, coder keys and the Peertalk framing are otherwise unchanged.

### Readable version

- `SPLK_SERVER_READABLE_VERSION` equals the app's `MARKETING_VERSION`. Client and server are released together from one tag.
- `release.yml` bumps it in `SPLKDefines.h` alongside `MARKETING_VERSION`.
- The outdated-server hint compares the connected server's readable version with the client's own `SPLK_SERVER_READABLE_VERSION`. It no longer asks `lookin.work/queryversion.json`, so `SPLKServerVersionRequestor` is removed and its two defaults keys go unread.

## Documents

- Supa Lookin writes `.supalookin` documents of type `icu.retrouvailles.supalookin.document`, an exported UTI conforming to `public.data`. SPLKServer's on-device export writes the same extension.
- `.lookin` documents (`com.lookin.lookin`) become an imported UTI the app can only view, so it no longer claims stock Lookin's type:
  - Reading one maps every stock class name (`LookinHierarchyFile`, `LookinDisplayItem`, …) to its `SPLK` class on the unarchiver.
  - The file's version is checked against stock Lookin's supported range, 7.

## macOS app

- `Packages/LookinShared` is replaced by a local package reference to the repository root.
- User-facing text about the iOS library names `SPLKServer` and SPM:
  - The Help menu drops "Integrate by CocoaPods" and its `pod` line. The SPM item copies `https://github.com/weirui-kong/SupaLookin`, and "Integration Guide" opens its README.
  - The SPLKServer entries under "Source Code at GitHub" and "Report Issues" open this repository. The macOS app entries still open `hughkli/Lookin`.
  - The version messages in `Localizable.strings` (en, zh-Hans) are reworded for SPLKServer and no longer link to `lookin.work`. The outdated-server hint's "Check out version updates on GitHub…" opens this repository's releases.
  - The MCP `get_status` hint mentions SPLKServer.
- Comments that quote stock port numbers quote SPLKServer's.

## Licensing

`Sources/` is derived from LookinServer and stays MIT. `Sources/LICENSE` carries upstream's notice. The root `LICENSE` (GPLv3) covers the macOS app, and `README.md` states the split.

## Documentation

- `AGENTS.md` describes the `SPLK` naming, the `Sources/` packages and the new-code-in-Swift rule.
- `README.md` documents integrating SPLKServer.
- `Docs/MCP.md` refers to SPLKServer.

## Verification

- The macOS app builds in Debug and Release, and `SupaLookinTests` pass.
- `SPLKServer` builds for the iOS Simulator in Debug and Release. The Release build has no `SPLK` Objective-C classes.
- An iOS app linking SPLKServer is found and inspected by Supa Lookin: its hierarchy loads, screenshots render, an attribute change applies, and a console method invocation returns.
- No `Lookin`, `LKS` or `LK` name prefix is left in `Sources/`, `SupaLookin/` or `SupaLookinTests/`, apart from coder keys, defaults keys and the stock class names mapped for `.lookin` documents (`grep`).

## Out of scope

- A demo iOS app in this repository.
- Splitting the shared code and the server into separate targets.
- Moving Sparkle updates off `lookin.work` (still pending from `20261025-spm-migration.md`), and the other `lookin.work` help links.

## Update: e2e demo (see `20261110-protocol-v2-m2-server.md`)

The repository now holds a demo app's sources under `Scripts/e2e/` for end-to-end tests. It is a Swift file and an `Info.plist` built by `Scripts/e2e-sim.sh`, not an Xcode project. "A demo iOS app in this repository" under Out of scope no longer applies.
