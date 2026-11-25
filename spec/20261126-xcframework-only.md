# SPLKServer ships only as an xcframework

## Summary

Apps get SPLKServer only as `SPLKServer.xcframework.zip`, the prebuilt framework each release already carries (`20261118-xcframework-release.md`). The Swift package is no longer a way to integrate it, and CocoaPods never was.

With one prebuilt binary as the only build an app ever gets, SPLKServer no longer has to empty itself out of an app's Release builds. The configuration half of its compile guards goes away: `SHOULD_COMPILE_SPLK_SHARED` is removed, and `SHOULD_COMPILE_SPLK_SERVER` becomes a plain platform check. Keeping SPLKServer out of an app's Release builds is up to the app, by not embedding the framework there.

## The package

`Package.swift` stays at the repository root. It builds Supa Lookin's shared code, the framework, the tests, and SPLK Chat, which builds SPLKServer from source. Its products and targets don't change.

It no longer sets any compile macros: `sharedDefines`, `sharedSwiftDefines` and `serverSwiftDefines` go, along with the `SHOULD_COMPILE_SPLK_SERVER` define of `SPLKServerSwift`.

An app that still pulls a newer tag through SPM keeps building, but now gets the server in every configuration, Release included. The README tells such apps to switch to the framework.

## Compile guards

- **`SHOULD_COMPILE_SPLK_SHARED`** is removed with the `#if` / `#endif` pairs it was the condition of. Shared and Base code compiles wherever its target does.
- **`SHOULD_COMPILE_SPLK_SERVER`** becomes the platform check it amounted to once the configuration is gone: the server builds for iOS, the iOS Simulator and the other UIKit platforms, never for macOS, where the package's Objective-C targets give Supa Lookin its models.
  - Objective-C: `#if TARGET_OS_IPHONE`. A file whose guard comes before its first import includes `<TargetConditionals.h>` right above it, since an undefined `TARGET_OS_IPHONE` would read as 0 and silently drop the file.
  - Swift: `#if canImport(UIKit)`.
- `Scripts/generate-protocol.sh` stops wrapping generated code in a guard.

## The framework

Built as today: the `SPLKServerDynamic` product in the Debug configuration, with Release's optimization (`20261118-xcframework-release.md`, "Update: the framework is optimized"). Debug still matters because it keeps `NSAssert` and the rest as before; it no longer decides whether the server compiles. Its slices stay iOS and the iOS Simulator, so tvOS, visionOS and Mac Catalyst apps no longer have a way in.

## SPLK Chat

It keeps building SPLKServer from the package. Its Release builds now have a working server too, so the README and `build-ipa.sh` drop their Debug-only notes. The IPA script still builds Debug.

## Text for apps

- **README**, "Integrating SPLKServer": the framework is the way in. Download it from the latest release, add it with **Embed & Sign**, or use it as a SwiftPM `binaryTarget` with the URL and checksum from the release notes. Keep it out of Release builds: it runs in any build it's in. iOS 15 and the iOS Simulator only. The ports and hooks notes stay. Apps on the Swift package switch to the framework.
- **Release notes**: the framework section drops "for apps that would rather embed a binary than build the Swift package" and says to keep it out of Release builds because it runs in any build it's in.
- **Help menu**: "Integrate by SPM (Click to Copy)" and the repository URL under it become "Download SPLKServer.xcframework" and the latest release's URL, which opens in the browser. "Integration Guide" still opens the README.

## Older specs

`20261109-splk-server.md` and `20261118-xcframework-release.md` each get an appended note pointing here.

## Verification

- Package tests pass, and `SupaLookinTests` pass.
- No `SHOULD_COMPILE_SPLK` is left in the repository outside older specs.
- On macOS, the package's server code stays out: Supa Lookin builds and links no server classes.
- SPLK Chat builds in Debug and Release. On the iPhone 12 mini, a Release build listens and `SPLKScreenshotFormatLiveTests` pass against it.
- `Scripts/build-xcframework.sh` builds both slices, and `otool -L` shows no dependency outside the system.
