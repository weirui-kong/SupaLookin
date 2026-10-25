# Agent Instructions — SupaLookin

Shared instructions for any coding agent working in this repository (Claude Code, Codex, or otherwise). `CLAUDE.md` at the repo root points here so there is a single source of truth.

## Hard constraints

1. **Never commit, push, or perform any other git write/publish operation unless the user has explicitly authorized it for that specific action.** Do not assume a prior approval carries over to a later change. When in doubt, stop and ask instead of acting.
2. **Work in spec mode.** Every non-trivial change is driven by a spec document under [`spec/`](spec/README.md) before implementation starts. Read `spec/README.md` for the full rules on how specs are named, versioned, and maintained.
3. **Follow Lookin's original style when iterating.** Match the existing codebase's conventions — code style, architecture patterns, naming, UI/UX idioms — rather than introducing a different style of your own. New code should read as a natural continuation of the original Lookin project, not a rewrite in a different voice.

   **Exception — file header, new files only:** every newly created source file uses this header (matches the original Lookin comment-header shape, with the new author line):

   ```
   //
   //  <filename>
   //  <module/target name>
   //
   //  Created by Weirui Kong on <yyyy/m/d>.
   //
   ```

   Do not retrofit this onto existing files — leave their original headers (e.g. `Created by 李凯 on ...`) untouched.

   **Comments:** don't write a comment unless it's necessary; if it is, keep it concise. Never write a comment that describes what the code does — add one only when *not* having it would leave a reader confused or likely to misread the code (a non-obvious *why*: a workaround, a quirk, a subtle constraint). Leave the original repository's existing comments untouched; only touch one if there's a specific need to (e.g. the code it describes changed).

## Project context

SupaLookin is an independent, long-term continuation of the unmaintained `hughkli/Lookin` (macOS UI inspector) and `QMUI/LookinServer` (iOS-side instrumentation library). See `.private/LICENSE_REVIEW.md` (local-only, not committed) for the licensing audit behind this fork: the macOS client is GPLv3, the iOS-side/shared library is MIT, and they're independent works connected over network/USB rather than one statically-linked binary.

- App name: **Supa Lookin**
- Bundle ID: `icu.retrouvailles.supalookin`
- Xcode project/workspace/target: `SupaLookin.xcodeproj` / `SupaLookin.xcworkspace` / target `SupaLookin`
- Dependency management: CocoaPods (`Podfile`) — pods: AppCenter, ReactiveObjC, Sparkle, LookinShared (LookinServer)
