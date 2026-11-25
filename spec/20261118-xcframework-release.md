# Releasing SPLKServer as an xcframework

## Summary

Each GitHub Release also carries `SPLKServer.xcframework.zip`: SPLKServer built as a dynamic framework for iOS devices and the iOS Simulator. An app can then embed a prebuilt binary instead of building the Swift package and its swift-protobuf dependency.

The Swift package stays the main way to integrate, and nothing about it changes. Keeping the framework out of an app's Release builds is up to the app; the framework does nothing there anyway, since it's built in Debug.

## The framework

**Contents**: `SPLKServer.xcframework` holds two `SPLKServer.framework`s:

| Slice | Architectures |
|---|---|
| `ios-arm64` | iOS devices |
| `ios-arm64_x86_64-simulator` | the iOS Simulator |

Each is a dynamic framework with SPLKServer, SPLKServerSession and everything they use linked in, swift-protobuf included. It has no headers and no Swift module: nothing in an app calls SPLKServer, which starts itself once the app finishes launching. The hooks an app implements (`splk_customDebugInfos` and the rest) are found through the Objective-C runtime, so they need no import either.

**Built from**: the package's `SPLKServerDynamic` product, built with `xcodebuild` in the Debug configuration, since SPLKServer only compiles its server in Debug (see `20261109-splk-server.md`). Each slice is then renamed and labeled:
- the framework folder and binary become `SPLKServer`, and the binary's install name becomes `@rpath/SPLKServer.framework/SPLKServer`;
- `Info.plist` gets `CFBundleIdentifier` `org.supacode.app.lookin.splkserver`, `CFBundleName` and `CFBundleExecutable` `SPLKServer`, and the release's version as `CFBundleShortVersionString` and `CFBundleVersion`.

Its minimum iOS is the package's iOS 13, raised to the oldest the building Xcode targets (iOS 15 with Xcode 27).

The frameworks are left unsigned; Xcode signs them when an app embeds them.

**The script**: `Scripts/build-xcframework.sh` does all of this and writes `build/xcframework/SPLKServer.xcframework.zip`, then prints the zip's SwiftPM checksum (`swift package compute-checksum`). It runs the same locally and in the workflow. It takes the version from `SPLK_SERVER_READABLE_VERSION` in `Sources/SPLKServer/include/SPLKDefines.h`.

## The release

`release.yml` runs the script after building the app, so the framework carries the version just bumped. `gh release create` attaches `SPLKServer.xcframework.zip` beside the DMG.

The release notes gain a section after the install steps:

````
## SPLKServer.xcframework

SPLKServer for iOS and the iOS Simulator, prebuilt, for apps that would rather embed a binary than build the Swift package. Add `SPLKServer.xcframework` to your app target with **Embed & Sign**. It works in Debug builds only; keep it out of your Release builds.

With Swift Package Manager, from a package of your own:

```swift
.binaryTarget(
    name: "SPLKServer",
    url: "https://github.com/weirui-kong/SupaLookin/releases/download/vX.Y.Z/SPLKServer.xcframework.zip",
    checksum: "<checksum>"
)
```
````

with the version and checksum filled in.

## README

"Integrating SPLKServer" gains a short paragraph on the prebuilt framework, pointing at the latest release and repeating the Embed & Sign and Debug-only notes.

## Verification

- **The script, locally**:
  - the zip unpacks to the two slices with the architectures above;
  - each binary's install name and `Info.plist` are as above;
  - `otool -L` shows no dependency on swift-protobuf or any other non-system library.
- **An app embedding it**: the e2e demo, compiled against the simulator slice and with the framework in its `Frameworks` folder, launches on a simulator, and Supa Lookin finds it through MCP's `list_apps`.
- **SwiftPM**: a package with a `binaryTarget` pointing at the zip by path resolves, and an iOS Simulator build of it succeeds.

## Out of scope

- tvOS, visionOS and Mac Catalyst slices.
- A CocoaPods podspec.
- Signing the framework.

## Update: the framework is optimized

The framework is still built in the Debug configuration, since that's what compiles the server, but with Release's optimization: the script passes `SWIFT_OPTIMIZATION_LEVEL=-O`, `SWIFT_COMPILATION_MODE=wholemodule`, `GCC_OPTIMIZATION_LEVEL=s` and `ENABLE_TESTABILITY=NO`. Everything else stays as in Debug, `NSAssert` included. Nothing changes for an app embedding it: the zip, its contents and the Debug-only note are the same.

Verified by building SPLK Chat with the same settings and running `SPLKMaskLiveTests` against it on a device.

## Update: the only way in (see `20261126-xcframework-only.md`)

The framework is now the only way apps integrate SPLKServer; the Swift package isn't one any more. The server no longer depends on the Debug configuration to compile, so the framework runs in any build it's embedded in, and the README and release notes say to keep it out of Release builds for that reason. The script still builds Debug, now only for `NSAssert` and the rest.
