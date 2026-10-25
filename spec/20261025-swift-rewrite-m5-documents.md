# Swift rewrite M5: documents and the rest

## Summary

Last milestone of [`20261025-swift-rewrite.md`](20261025-swift-rewrite.md). It ports the remaining modules and the app delegate, which leaves no Objective-C in `SupaLookinNext`:

- `Export/`: `LKExportManager`, `LKExportAccessoryView`, `LookinDocument`
- `Read/`: the window for opened `.lookin` files, with its own `LKPreferenceManager`
- `Preference/`, `Tutorial/`, `About/`, `DanceScript/`
- `AppDelegate`

`LKPreferenceSwitchView` isn't ported: nothing in the Objective-C app uses it. Neither is `LKPreferenceViewController`'s unreferenced `_handleDebugButton`.

`logo_jump.gif` and `DanceScript.sh` join the Swift target's resources from `LookinClient/`, like the asset catalog and strings did in M0.

## API shape

| Objective-C | Swift |
|---|---|
| `dataFromHierarchyInfo:imageCompression:fileName:` (out parameter) | `data(from:imageCompression:) -> (data: Data?, fileName: String?)` |
| `LookinDocument dataOfType:error:` / `readFromData:ofType:error:` | `data(ofType:) throws` / `read(from:ofType:) throws`. `read` is `nonisolated`, as `NSDocument` declares it. |
| `NSTask launch` | `Process.run()` |
| `RACObserve(LKPreferenceManager.mainManager, appearanceType)` in `AppDelegate` | `appearanceTypePublisher` |

## Behavior that stays

- `.lookin` files are written with `NSKeyedArchiver` (secure coding) under type `com.lookin.lookin`, with LZW-TIFF screenshots keyed by layer oid, and are read and verified with `+[LookinHierarchyFile verifyHierarchyFile:]`. Files from either app open in the other.
- The export file name is `<app>_ios<major>_<MMddHHmm>.lookin`, and the compression choices are 10/30/50/75/100%.
- The read window has its own preference manager, so its toolbar and menu settings don't affect the static window.
- Tutorial flags use the same `NSUserDefaults` keys, and a popover counts as learned when closed by its button or after 1.8 s.
- Preferences keep the same options, the reset button and its DEBUG extras.
- The About window picks one of the four photos with its mask alpha at random.
- `AppDelegate` sets up the menu before launch finishes, follows the appearance preference, shows the launch window unless a file was opened, removes the UIImageView temp files on quit, and runs the DEBUG identifier checks.

## Deviations

1. **Dance script launch failure.** `-[NSTask launch]` raised an exception when the script couldn't run. `Process.run()` throws, and the failure is logged.

## Behavior checklist

- [ ] Export from the static window writes a file the Objective-C app opens, and vice versa; the file-size label follows the quality menu.
- [ ] Opening a `.lookin` file from Finder, by drag-and-drop, and with "Open in new window"; an old or foreign file shows the same errors.
- [ ] The read window's toolbar, menu actions, measure and focus tip.
- [ ] Preferences: every popup and the reset button.
- [ ] Tutorials appear once each and stop after "Do not show again".
- [ ] About window, DanceUI "Navigate…" button.

## Verification

- `SupaLookinNextTests` covers a `.lookin` round trip through `LKExportManager` and `LookinDocument`.
- The checklist above, item by item.

## Out of scope

- Cutover (scheme, bundle id, Sparkle, removing `LookinClient/`), which has its own spec per the master spec.
