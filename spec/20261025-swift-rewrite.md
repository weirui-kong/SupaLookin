# Swift rewrite of the app layer

## Summary

The macOS app layer is rewritten in Swift as a new app target, `SupaLookinNext`, built from scratch next to the existing Objective-C app (`LookinClient/`, target `SupaLookin`). The goal is 1:1 parity: same behavior, same UI, same strings, same data formats. Only the implementation language and its idioms change.

The Objective-C app stays maintained and keeps shipping until the Swift app reaches parity. At cutover the Swift target takes over the `SupaLookin` name, bundle ID and release pipeline, and the Objective-C app is deleted.

This spec fixes the rules shared by the whole rewrite. Each milestone below gets its own spec before its implementation starts.

## Prerequisite

[`20261025-spm-migration.md`](20261025-spm-migration.md) lands first. The Swift target consumes `Packages/LookinShared` and Sparkle 2 through SPM, and it never links ReactiveObjC or AppCenter.

## What stays Objective-C

`Packages/LookinShared` (the shared protocol models, plus Peertalk) stays Objective-C permanently, and both targets link the same package.

- **Wire format:** the iOS side (LookinServer) is Objective-C. Requests and responses travel as `NSKeyedArchiver` archives that record Objective-C class names and coding keys, so the classes on both ends have to match.
- **`.lookin` files:** documents are `NSKeyedArchiver` archives of `LookinHierarchyFile`. Files exported by either app, or by the original Lookin, must keep opening.

Swift uses these types directly through `import LookinShared`. The client-side Objective-C categories on them (`LookinDisplayItem+LookinClient`, `LookinObject+LookinClient`, `LookinAttributesGroup+LookinClient`, `LookinAttributesSection+LookinClient`, `LookinAutoLayoutConstraint+LookinClient`, `LookinCustomDisplayItemInfo+LookinClient`) are ported as Swift extensions in the app target.

## Target & layout

| | During the rewrite | After cutover |
|---|---|---|
| Target | `SupaLookinNext` | `SupaLookin` |
| Sources | `SupaLookin/` | `SupaLookin/` (unchanged) |
| Product name | `Supa Lookin Next` | `Supa Lookin` |
| Bundle ID | `icu.retrouvailles.supalookin.next` | `icu.retrouvailles.supalookin` |
| Updates | Sparkle linked, no updater started | Sparkle updater started as in the Objective-C app |

- The separate bundle ID lets both apps be installed and run side by side for comparison, each with its own `NSUserDefaults` domain. At cutover the Swift app takes over the real bundle ID, so existing users' preferences carry over as long as every key is unchanged (see Data compatibility).
- `SupaLookin/` mirrors `LookinClient/`'s module folders (`Base`, `Connection`, `Dashboard`, `Hierarchy`, `Static`, …), so a ported file sits at the path matching its original.
- Shared resources: both targets use the same `Assets.xcassets` and the same `en.lproj` / `zh-Hans.lproj` `Localizable.strings` through target membership, so images and strings can't drift apart. They move under `SupaLookin/` at cutover.
- `SupaLookinNext` has its own `MainMenu.xib` and `Info.plist`, copied from the Objective-C app and pointed at the Swift classes. The document types and UTType declarations are identical.
- A unit test target `SupaLookinNextTests` covers non-UI logic, where the Objective-C behavior can be pinned down as test cases: data-source flattening and search, value formatting, demangling, preference defaults.

## Language & frameworks

- **Toolchain:** Swift 6 language mode with strict concurrency checking. App-target default actor isolation is `MainActor`.
- **Deployment target:** macOS 14.0, unchanged.
- **UI:** AppKit only, matching the original view and controller structure. No SwiftUI. SceneKit stays for the 3D preview.
- **Concurrency:** LookinShared types aren't `Sendable`, so they stay on the main actor. Connection I/O hops to the main actor before handing them out, which is where the Objective-C app also delivered them.
- **Carried over:** the Objective-C target's existing Swift files (`CwlDemangle.swift`, `LKSwiftDemangler.swift`) are carried over, changed only as needed to compile in Swift 6 mode. CwlDemangle keeps its original header and license notice.

## Translation rules

These follow from constraint 3 in `AGENTS.md` (1:1 behavior and names, idiomatic Swift):

| Objective-C | Swift |
|---|---|
| `RACSignal` that delivers one value (most `LKInspectableApp` requests) | `async throws` function |
| `RACSignal` that delivers several values (e.g. `fetchHierarchyDetailWithTaskPackages:`, whose response arrives in chunks counted by `dataTotalCount`) | `AsyncThrowingStream` |
| Explicit cancellation (`cancelHierarchyDetailFetching`: `cancelRequestWithType:` + `LookinPush_CanceHierarchyDetails`) | The same explicit call, which also finishes the in-flight stream |
| `RACSubject` (`channelWillEnd`, `didReceivePush`, `itemsDidChangeFrame`, …) | Combine `PassthroughSubject` |
| `RACObserve` on a property the app owns | `@Published` + Combine subscription |
| `RACObserve` on an AppKit-owned property | KVO publisher |
| `deliverOn:[RACScheduler mainThreadScheduler]` | `@MainActor` |
| ShortCocoa `$()` layout | Frame-based layout in `layout()` / `resizeSubviews(withOldSize:)` with the same metrics, using small `NSView` frame helpers in `Base` |
| Category on a LookinShared or AppKit class | Swift extension, file named `<Class>+LookinClient.swift` |
| `+sharedInstance` singletons | `static let sharedInstance`, keeping the original name |

RAC signals are cold: the request goes out on subscribe, and every subscriber triggers its own request. Each call site gets checked individually, so the Swift version sends the same number of requests at the same moments and cancels them the same way.

## Data compatibility

These must stay byte- and key-identical with the Objective-C app:

- Every `NSUserDefaults` key in `LKPreferenceManager`, and every other key the app reads or writes, with the same value types and defaults.
- The `.lookin` document format, its UTType and its file extension.
- `Localizable.strings` keys, guaranteed by sharing the files.
- The LookinServer protocol, guaranteed by sharing `Packages/LookinShared`.

## Milestones

Each one gets its own spec listing the files it ports and the parity checks it must pass.

| # | Scope (`LookinClient/` folders, Objective-C size) |
|---|---|
| M0 | Scaffold: `SupaLookinNext` and `SupaLookinNextTests` targets, package links, Swift settings, shared resources. The app launches to an empty window, and CI builds the target on every push without releasing it. |
| M1 | Foundation: `Base` (~6.5k lines: controls, outline/table views, panels, categories), the replacement for ShortCocoa's layout helpers, `Manager` (~1.5k: preferences, navigation, menu, helper), `Other` |
| M2 | `Connection` (~1.1k): port scanning, Peertalk channels, request/response/push, `LKAppsManager`, `LKInspectableApp` |
| M3 | Inspecting an app: `Launch`, `Static` (~3.9k: data source, async update manager, 2D/3D preview), `Hierarchy` (~3.0k), `Toolbar` |
| M4 | `Dashboard` (~5.9k: attribute inspector, modifications, method search), `Console`, `Measure` |
| M5 | `Export` / `Read` (`.lookin` documents), `Preference`, `Tutorial`, `About`, `DanceScript` |
| M6 | Cutover (see below) |

The MCP server is built only in the Swift app, on top of M2's connection layer and M3's hierarchy state, under its own spec. It can land before cutover and doesn't block it. The Objective-C app gets no MCP.

## Parity verification

- Every milestone spec includes a checklist of user-visible behaviors in its scope. Each item is checked with both apps against the same iOS app running stock LookinServer, one app connected at a time.
- `.lookin` files exported by either app open in the other with identical hierarchy, attributes and screenshots.
- Non-UI logic ported in a milestone gets `SupaLookinNextTests` cases derived from the Objective-C implementation.

## Maintaining the Objective-C app

- Until cutover, the Objective-C app gets bug fixes and releases only. New features go to the Swift app.
- If a behavior fix lands in the Objective-C app for a module that's already ported, the same fix lands in the Swift app, and the fix's spec says so.
- The release workflow keeps building and releasing only the Objective-C target until cutover.

## Cutover

Done under its own spec once M1–M5 have passed their parity checks:

- Delete the Objective-C target, `LookinClient/` and `Packages/ReactiveObjC`.
- Rename `SupaLookinNext` to `SupaLookin` and switch to the real product name and bundle ID.
- Start the Sparkle updater.
- Move the shared resources under `SupaLookin/`.
- Point the release workflow at the Swift target, on a runner whose Xcode meets the toolchain requirement.
- Update `AGENTS.md`'s project context.

## Out of scope

- Rewriting LookinShared or Peertalk, or changing the LookinServer protocol.
- Any UI redesign or behavior change. Each one would need its own spec, and preferably comes after cutover.
- SwiftUI.
- The MCP server's design, which goes in its own spec.
- Moving updates to a SupaLookin-owned appcast.
