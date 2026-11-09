# Agent Instructions — SupaLookin

Shared instructions for any coding agent working in this repository (Claude Code, Codex, or otherwise). `CLAUDE.md` at the repo root points here so there is a single source of truth.

## Hard constraints

1. **Never commit, push, or perform any other git write/publish operation unless the user has explicitly authorized it for that specific action.** Do not assume a prior approval carries over to a later change. When in doubt, stop and ask instead of acting.
2. **Work in spec mode.** Every non-trivial change is driven by a spec document under [`spec/`](spec/README.md) before implementation starts. Read `spec/README.md` for the full rules on how specs are named, versioned, and maintained.
3. **Keep Lookin's behavior; write new code in idiomatic Swift.** The macOS app was rewritten in Swift from Lookin's Objective-C client (see [`spec/20261025-swift-rewrite.md`](spec/20261025-swift-rewrite.md)). SupaLookin ships its own iOS-side library, SPLKServer, and no longer talks to stock LookinServer (see [`spec/20261109-splk-server.md`](spec/20261109-splk-server.md)).

   - **Behavior follows Lookin.** Logic, data flow, UI layout, interactions, user-facing strings and localization keys match the original Lookin and LookinServer. Don't redesign, "improve", or drop behavior in passing; any intentional behavior change goes through its own spec.
   - **Every name uses the `SPLK` prefix.** Lookin's `LK`, `LKS` and `Lookin` prefixes all became `SPLK` (`LKConnectionManager` → `SPLKConnectionManager`, `LookinDisplayItem` → `SPLKDisplayItem`, `lks_oid` → `splk_oid`). Swap the prefix back to trace a type to its Lookin counterpart. New types take the `SPLK` prefix too. Stored keys (`NSCoder` keys, `UserDefaults` keys) keep their original values.
   - **New code is Swift where possible.** Existing Objective-C stays Objective-C. An SPM target is either Swift or Objective-C, and target dependencies can't form a cycle, so new Swift for the library goes in a Swift target that the Objective-C target depends on, or one that depends on the Objective-C target, never both.
   - **Language-level optimizations are allowed; behavior is not negotiable.** Swift-specific improvements (types, safety, concurrency, simpler data flow) are welcome, but business logic, UI presentation and interaction logic must match the original exactly.
   - **Code style is Swift's, not transliterated Objective-C.** Use the Swift API Design Guidelines and native Swift constructs (value types, optionals, enums with associated values, `async`/`await`, Combine) wherever they express the same behavior. Don't reproduce Objective-C-only patterns such as ReactiveObjC signals or ShortCocoa's `$()` syntax.
   - **No Objective-C in the app target.** It has no `.h` / `.m` files and no bridging header. `@objc` appears only where AppKit's runtime leaves no Swift route (nib-instantiated classes, selector-based target-action, KVO on AppKit-owned properties). Objective-C lives only under `Sources/`.
   - **Objective-C code keeps Lookin's style.** When touching the Objective-C under `Sources/`, match the existing code's conventions.

   **File header, new files only:** every newly created source file uses this header (matches the original Lookin comment-header shape, with the new author line):

   ```
   //
   //  <filename>
   //  <module/target name>
   //
   //  Created by Weirui Kong on <yyyy/m/d>.
   //
   ```

   Do not retrofit this onto existing files — leave their original headers (e.g. `Created by 李凯 on ...`) untouched. A Swift file ported from an Objective-C file is a new file and gets this header.

   **Comments:** don't write a comment unless it's necessary; if it is, keep it concise. Never write a comment that describes what the code does — add one only when *not* having it would leave a reader confused or likely to misread the code (a non-obvious *why*: a workaround, a quirk, a subtle constraint). Leave the original repository's existing comments untouched; only touch one if there's a specific need to (e.g. the code it describes changed). When porting, the original comments may be carried over into the Swift code. Commented-out code is not ported.

## Project context

SupaLookin is an independent, long-term continuation of the unmaintained `hughkli/Lookin` (macOS UI inspector) and `QMUI/LookinServer` (iOS-side instrumentation library), and no longer interoperates with either. See `.private/LICENSE_REVIEW.md` (local-only, not committed) for the licensing audit behind this fork: the macOS client is GPLv3, the iOS-side/shared library under `Sources/` is MIT, and they're independent works connected over network/USB rather than one statically-linked binary.

- App name: **Supa Lookin**
- Bundle ID: `icu.retrouvailles.supalookin`
- Xcode project/target: `SupaLookin.xcodeproj` / target `SupaLookin`
- App sources: `SupaLookin/` (Swift); tests: `SupaLookinTests/`
- iOS-side library: the `SPLKServer` product of the root `Package.swift`, sources under `Sources/`:
  - `SPLKServer`, `SPLKServerSwift`, `SPLKServerBase`: Lookin's models and builders (Objective-C, plus upstream's Swift ivar tracing)
  - `SPLKProtocol`: protocol v2, shared by both ends (Swift, generated from `Sources/SPLKProtocol/Schema/splk.proto` by `Scripts/generate-protocol.sh`)
  - `SPLKModelBridge`: converts between the models and v2 messages (Swift)
  - `SPLKServerSession`: the iOS server runtime (Swift)

  The macOS app links the `SPLKServer` and `SPLKModelBridge` products as a local package. `Scripts/e2e-sim.sh` runs the end-to-end tests against a demo app on the simulator.
- Ports: SPLKServer listens on 47264–47269 (simulator) and 47275–47279 (USB device), clear of stock LookinServer's
- Dependency management: Swift Package Manager — the root package, plus Sparkle 2, the MCP swift-sdk and FlyingFox
