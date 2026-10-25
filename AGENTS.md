# Agent Instructions — SupaLookin

Shared instructions for any coding agent working in this repository (Claude Code, Codex, or otherwise). `CLAUDE.md` at the repo root points here so there is a single source of truth.

## Hard constraints

1. **Never commit, push, or perform any other git write/publish operation unless the user has explicitly authorized it for that specific action.** Do not assume a prior approval carries over to a later change. When in doubt, stop and ask instead of acting.
2. **Work in spec mode.** Every non-trivial change is driven by a spec document under [`spec/`](spec/README.md) before implementation starts. Read `spec/README.md` for the full rules on how specs are named, versioned, and maintained.
3. **Keep 1:1 parity with Lookin; write the new app in idiomatic Swift.** The app layer is being rewritten in Swift as a new target, alongside the original Objective-C app (see [`spec/20261025-swift-rewrite.md`](spec/20261025-swift-rewrite.md)).

   - **Behavior is 1:1.** Logic, data flow, UI layout, interactions, user-facing strings and localization keys match the Objective-C app (`LookinClient/`). Don't redesign, "improve", or drop behavior while porting; any intentional behavior change goes through its own spec.
   - **Names map 1:1.** A ported type keeps its original name, `LK` prefix included (`LKConnectionManager` stays `LKConnectionManager`), so every Swift type can be traced back to its Objective-C counterpart. Members take the name the Swift importer would give the original selector.
   - **Code style is Swift's, not transliterated Objective-C.** Use the Swift API Design Guidelines and native Swift constructs (value types, optionals, enums with associated values, `async`/`await`, Combine) wherever they express the same behavior. Don't reproduce Objective-C-only patterns such as ReactiveObjC signals or ShortCocoa's `$()` syntax.
   - **Objective-C code keeps Lookin's style.** When touching the Objective-C app or the vendored packages under `Packages/`, match the existing code's conventions as before.

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

   **Comments:** don't write a comment unless it's necessary; if it is, keep it concise. Never write a comment that describes what the code does — add one only when *not* having it would leave a reader confused or likely to misread the code (a non-obvious *why*: a workaround, a quirk, a subtle constraint). Leave the original repository's existing comments untouched; only touch one if there's a specific need to (e.g. the code it describes changed). When porting, carry over an original comment only if it still explains a non-obvious *why* in the Swift code.

## Project context

SupaLookin is an independent, long-term continuation of the unmaintained `hughkli/Lookin` (macOS UI inspector) and `QMUI/LookinServer` (iOS-side instrumentation library). See `.private/LICENSE_REVIEW.md` (local-only, not committed) for the licensing audit behind this fork: the macOS client is GPLv3, the iOS-side/shared library is MIT, and they're independent works connected over network/USB rather than one statically-linked binary.

- App name: **Supa Lookin**
- Bundle ID: `icu.retrouvailles.supalookin`
- Xcode project/target: `SupaLookin.xcodeproj` / target `SupaLookin`
- Swift rewrite: target `SupaLookinNext`, sources under `SupaLookin/`; it replaces the Objective-C target at cutover (see the rewrite spec)
- Dependency management: Swift Package Manager — local packages `Packages/LookinShared` and `Packages/ReactiveObjC` (vendored, see each `UPSTREAM.md`), plus Sparkle 2
