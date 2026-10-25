# Swift rewrite cutover

## Summary

Final step of [`20261025-swift-rewrite.md`](20261025-swift-rewrite.md), done after M1–M5 passed their parity checks. The Swift target becomes the shipping app and the Objective-C app is removed.

## Changes

- **Removed:** the Objective-C `SupaLookin` target, its `SupaLookin` and `LookinTestflight` schemes, `LookinClient/`, and `Packages/ReactiveObjC`, which only the Objective-C app used.
- **Shared resources move under `SupaLookin/`**, where the synchronized folder picks them up:
  - `Assets.xcassets`, `lookin_icon.icns`, `logo_jump.gif`
  - `DanceScript/DanceScript.sh`
  - `en.lproj` / `zh-Hans.lproj` with `Localizable.strings` and `MainMenu.strings`. The menu translations now reach the Swift app, whose `MainMenu.xib` keeps the original object IDs.
  - `Lookin.entitlements`, excluded from the bundle like `Info.plist`
- **The Swift target takes over the app's identity:**

  | Setting | Value |
  |---|---|
  | Target / scheme | `SupaLookin` (tests: `SupaLookinTests`) |
  | `PRODUCT_NAME` | `Supa Lookin` |
  | Bundle ID | `icu.retrouvailles.supalookin` (tests: `icu.retrouvailles.supalookin.tests`) |
  | `MARKETING_VERSION` | the released version, continued by the release workflow |
  | `CURRENT_PROJECT_VERSION` | `14`, the Objective-C app's build number, so Sparkle never sees the Swift app as older |

- **Sparkle:** the updater starts with the app. The feed URL and public key in `Info.plist` are unchanged.

## CI

- `release.yml` builds the `SupaLookin` scheme as before. The version bump reads `MARKETING_VERSION` from the app target's build settings, since the Swift target's settings no longer put it on the line next to the bundle ID.
- The per-push build-and-test workflow becomes `ci.yml` and runs the `SupaLookin` scheme's tests.

## Verification

- `SupaLookin` builds and its tests pass.
- The built `Supa Lookin.app` has bundle ID `icu.retrouvailles.supalookin`, contains the moved resources, and launches.

## Out of scope

- `AGENTS.md`'s project context, which still describes the two targets.
