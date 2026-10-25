# Swift rewrite M0: scaffold

## Summary

First milestone of [`20261025-swift-rewrite.md`](20261025-swift-rewrite.md). It adds the `SupaLookinNext` app target and the `SupaLookinNextTests` test target, links the packages, shares the resources, and adds CI that builds and tests the new target on every push. When it's done, `Supa Lookin Next` launches to an empty window under the copied main menu. No `LookinClient/` code is ported yet; that starts in M1.

## Project format

- `SupaLookin.xcodeproj` moves to the Xcode 16 project format (`objectVersion = 77`).
- `SupaLookin/` and `SupaLookinNextTests/` are added as file-system synchronized folders, so a Swift file created under them joins its target without a `project.pbxproj` edit. This matters across a rewrite of ~160 files.
- The Objective-C target's groups and build settings are left as they are.
- The project then needs Xcode 16 or later to open, so the release workflow moves to a newer runner (see CI).

## `SupaLookinNext` target

| Setting | Value |
|---|---|
| Product name | `Supa Lookin Next` |
| Module name (`PRODUCT_MODULE_NAME`) | `SupaLookin`, the final name, so nib `customModule`, `NSDocumentClass` and `@testable import` don't change at cutover |
| Bundle ID | `icu.retrouvailles.supalookin.next` |
| Deployment target | macOS 14.0 |
| `SWIFT_VERSION` | `6.0` |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` |
| `OTHER_SWIFT_FLAGS` | `-Xcc -DSHOULD_COMPILE_LOOKIN_SERVER=1`, so the Clang importer sees LookinShared's declarations, which are all wrapped in `#ifdef SHOULD_COMPILE_LOOKIN_SERVER` |
| Signing, hardened runtime, team | Same as the Objective-C target |
| Entitlements | The shared `LookinClient/Lookin.entitlements` |
| `MARKETING_VERSION` | `0.1.0`. The release workflow only bumps the target with the `icu.retrouvailles.supalookin` bundle ID, so this one is never touched. |

- **Packages:** links `LookinShared` and `Sparkle`. It never links `ReactiveObjC`.
- **Info.plist:** `SupaLookin/Info.plist` is a copy of `LookinClient_Info.plist`, with the same document types, UTType declarations and Sparkle keys. Name, bundle ID and version come from build settings, as in the Objective-C target.
  - The one exception is `NSDocumentClass`: it is `$(PRODUCT_MODULE_NAME).LookinDocument`. The Swift `LookinDocument` ported in M5 then resolves without an `@objc(LookinDocument)` name.
  - The plist is excluded from the synchronized folder's resource membership.
- **Shared resources**, added to this target through membership and left in place under `LookinClient/`:
  - `Assets.xcassets`
  - `en.lproj` and `zh-Hans.lproj` `Localizable.strings`
  - `lookin_icon.icns`
  
  The remaining resources (`logo_jump.gif`, `DanceScript.sh`) join in the milestone that ports the code using them.

### Sources added in M0

| File | Content |
|---|---|
| `SupaLookin/main.swift` | Port of `main.m`: calls `NSApplicationMain` |
| `SupaLookin/AppDelegate.swift` | `AppDelegate` that opens an empty window at launch. Later milestones replace it with the port of `AppDelegate.m`. |
| `SupaLookin/Base.lproj/MainMenu.xib` | Copy of the Objective-C app's `MainMenu.xib`, with `AppDelegate` resolved from the `SupaLookinNext` module. Its items stay inert until M1 ports `LKAppMenuManager`, which assigns their actions. |

All new files use the `AGENTS.md` file header. The target has no bridging header and no Objective-C sources, per the rewrite spec's "no Objective-C in the main project" rule. LookinShared reaches Swift as a Clang module through `import LookinShared`. `AppDelegate` needs no `@objc` name, since the nib resolves it through its `customModule`.

## `SupaLookinNextTests` target

- A unit-test bundle hosted by `SupaLookinNext`, written with Swift Testing.
- It depends on the `LookinShared` product so it can `import LookinShared`, but doesn't link it. The host app already links the package statically, and a second copy in the bundle would duplicate its Objective-C classes.
- M0 adds one test, which checks that LookinShared imports correctly: `LOOKIN_CLIENT_VERSION` is visible from Swift, and a `LookinDisplayItem` can be created and archived with `NSKeyedArchiver`.
- A shared `SupaLookinNext` scheme builds the app and runs this bundle in its test action.

## CI

- **New `.github/workflows/next.yml`:**
  - Trigger: every push and pull request.
  - Runner: `macos-26`.
  - Step: `xcodebuild -project SupaLookin.xcodeproj -scheme SupaLookinNext test`, with the same ad-hoc signing overrides as the release build.
  - No version bump, no release.
- **`release.yml`:** the runner changes from `macos-14` to `macos-26`. That image's default Xcode is 26.x, which opens the new project format and has Swift 6.2 for `SWIFT_DEFAULT_ACTOR_ISOLATION`. The workflow still builds and releases only the `SupaLookin` scheme.
- **Release spec:** an update section is appended to `20260925-release-workflow.md` recording the runner change.

## Verification

- Locally, both schemes build: `SupaLookin` in Release with the ad-hoc overrides, and `SupaLookinNext` with its tests passing.
- The Objective-C app launches and behaves as before.
- `Supa Lookin Next` launches to an empty window, with the copied main menu and its own name in the menu bar.
- After the push (which needs its own authorization), `next.yml` passes, and `release.yml` builds and releases on `macos-26`.

## Out of scope

- Porting anything from `LookinClient/`, including the carried-over Swift files (`CwlDemangle.swift`, `LKSwiftDemangler.swift`). They move in M1 together with the rest of `Base`.
