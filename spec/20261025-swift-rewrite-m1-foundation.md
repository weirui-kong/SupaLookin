# Swift rewrite M1: foundation

## Summary

Second milestone of [`20261025-swift-rewrite.md`](20261025-swift-rewrite.md). It ports the layer every other module builds on:

- **`Base/`:** the base views, controls and controllers, the outline/table views, panels, tips, input search, the Message attributes, and the categories.
- **`Manager/`:** `LKHelper`, `LKPreferenceManager`, `LKNavigationManager`, `LKAppMenuManager`.
- **`Other/`:** `LKServerVersionRequestor`, `LKVersionComparer`.

Each ported file sits under `SupaLookin/` at the path matching its original under `LookinClient/`. `Base/LKHierarchyDataSource.m` isn't compiled by the Objective-C target, so it isn't ported.

## ShortCocoa replacement

ShortCocoa isn't ported. Its layout calls become methods on `NSView` and `CALayer`, defined once in `SupaLookin/Base/LKFrameLayout.swift` and shared through the `LKFrameLayout` protocol. The semantics are ShortCocoa's own:

- Setters return `self`, so calls chain as ShortCocoa's did (`label.fitSize().centerVertically().setX(8)`).
- Setters snap to the backing pixel grid (`ceil(value × scale) / scale`).
- `fitSize()` / `fitHeight()` / `fitWidth()` reproduce ShortCocoa's `sizeToFit` / `heightToFit` / `widthToFit` as `ShortCocoa+LookinClient` swizzles them:
  - For an `LKBaseView` or an `NSControl`, they use `sizeThatFits(_:)` and don't snap.
  - For any other view they do nothing.
- Edge-relative calls (`alignBottom`, `extendToBottom`) respect `isFlipped` / `contentsAreFlipped`, as ShortCocoa did.

| ShortCocoa | Swift |
|---|---|
| `.x() .y() .width() .height() .size() .frame()` | `setX(_:)`, `setY(_:)`, `setWidth(_:)`, `setHeight(_:)`, `setSize(_:)`, `setFrame(_:)` |
| `.midX() .midY() .maxX() .maxY()` | `setMidX(_:)`, `setMidY(_:)`, `setMaxX(_:)`, `setMaxY(_:)` |
| `.offsetX() .offsetY()` | `offset(x:y:)` |
| `.right() .bottom()` | `alignRight(_:)`, `alignBottom(_:)` |
| `.toRight() .toBottom() .toMaxX() .toMaxY() .toY()` | `extendToRight(_:)`, `extendToBottom(_:)`, `extendToMaxX(_:)`, `extendToMaxY(_:)`, `extendToY(_:)` |
| `.fullWidth .fullHeight .fullFrame` | `fillWidth()`, `fillHeight()`, `fillSuperview()` |
| `.horAlign .verAlign .centerAlign` | `centerHorizontally()`, `centerVertically()`, `centerInSuperview()` |
| `.sizeToFit .heightToFit .widthToFit` | `fitSize()`, `fitHeight()`, `fitWidth()` |
| `.lk_maxWidth() .lk_minWidth()` | `limitWidth(max:)`, `limitWidth(min:)` |
| `$(a, b, …).groupX/MidY/HorAlign/…` and `.$groupX/MaxY/…` | the same operations on `[NSView]` (`groupMinX`, `setGroupMidY(_:)`, `centerGroupVertically()`, …) |
| `.visibles`, `.show`, `.hide` | `visibleViews`, and setting `isHidden` |
| `.$x .$maxY .$width …` (reading) | the plain `frame` properties (`frame.minX`, `frame.maxY`, `frame.width`, …) |
| `.$bestWidth .$bestHeight .$bestSize` | `bestWidth`, `bestHeight`, `bestSize` on `NSControl` |
| `$(string).textColor().font().lineHeight().addImage().attrString` | `LKAttributedStringBuilder` in `Base/LKAttributedStringBuilder.swift` |

## Macros and C helpers

Swift can't import LookinShared's function-like macros. `SupaLookin/Base/LookinShared+Swift.swift` defines them once:

| Macro | Swift |
|---|---|
| `LookinColorMake`, `LookinColorRGBAMake` | `NSColor(lookinRed:green:blue:alpha:)` |
| `LookinErr_Inner`, `LookinErr_NoConnect`, `LookinErr_ObjNotFound` | `LookinError.inner`, `.noConnect`, `.objNotFound` |
| `LookinErrorMake` | `LookinError.make(_:_:)` |
| `LookinErrorText_Timeout` | `LookinError.timeoutText` |

The localized strings stay byte-identical. The client's own macros from `LKHelper.h` become:

- `NSFontMake`: `NSFont.systemFont(ofSize:)`.
- `NSImageMake`: `NSImage(named:)`.
- The color macros: `static` members on `NSColor`, keeping their names (`NSColor.dashboardCardValueColor`, …).
- `InspectingApp`, `TutorialMng`, `CurrentKeyWindow`, `CurrentTime`: written out at each use (`LKAppsManager.sharedInstance.inspectingApp`, `LKTutorialManager.sharedInstance`, `NSApplication.shared.keyWindow`, `Date().timeIntervalSince1970`).
- `IsEnglish`: `LKHelper.isEnglish`.
- `AlertError` / `AlertErrorText`: `LKHelper.alertError(_:window:)` / `LKHelper.alertErrorText(_:_:window:)`, keeping the `LookinErrCode_Discard` exemption.
- `LKColorsCombine`: `LKTwoColors(lightMode:darkMode:)`.

## Categories

| Original | Swift |
|---|---|
| Categories on AppKit and Foundation types (`NSAppearance`, `NSArray`, `NSButton`, `NSColor`, `NSControl`, `NSPointerArray`, `NSString`, `NSView`, `NSString+Score`) | Swift extensions in `<Type>+LookinClient.swift`. Selector names lose their `lk_` prefix (e.g. `lk_isDarkMode` → `isDarkMode`); otherwise they follow the importer's rendering. |
| `LookinDisplayItem+LookinClient`, `LookinObject+LookinClient`, `LookinAttributesGroup+LookinClient`, `LookinCustomDisplayItemInfo+LookinClient`, `LookinAutoLayoutConstraint+LookinClient` | Swift extensions on the LookinShared types |
| State a category kept through `lookin_bindObject` (e.g. `NSView.backgroundColorName`) | Still `lookin_bindObject` / `lookin_getBindObject` from LookinShared |

## Behavior that stays

- `LKPreferenceManager` reads and writes the same `NSUserDefaults` keys, with the same defaults and value types.
- `LKBaseView` and `LKBaseControl` stay flipped.
- Appearance callbacks fire at the same moments.
- Hit-testing skips hidden or zero-alpha views.
- The menu tags in `LKAppMenuManager` stay identical, so the copied `MainMenu.xib` keeps working.
- Selector-based target-action goes through `LKActionTrampoline` (`onAction` on `NSControl`, `NSMenuItem`, `NSGestureRecognizer` and `NSToolbarItem`), so handlers are closures and the rest of the app has no `@objc` methods.
- `RACObserve` on a property becomes an `LKKVOSubject` publisher. It emits the current value on subscription and again once the setter has finished, which is when KVO's `didChange` fired.
- `LookinMsgAttribute` / `LookinMsgTargetAction` keep their subscribe/notify semantics. Subscribers are held weakly, and `sendAtOnce` fires immediately.

## Verification

- `SupaLookinNext` builds with no warnings from `SupaLookin/` other than the deprecations the Objective-C app also uses (`NSToolbarItem.minSize`, `NSScanner.scanDouble`, `NSWorkspace.openFile(_:withApplication:)`).
- `SupaLookinNextTests` covers the ported logic against values taken from the Objective-C implementation:
  - `NSColor` RGBA and hex strings
  - `NSString` scoring and `LKHelper.bestMatches`
  - `LKVersionComparer`
  - preference defaults, round-tripped through a scratch `UserDefaults` suite
  - pixel snapping and edge-relative layout in flipped and unflipped superviews
  - `LKKVOSubject` emission order

## Out of scope

- Anything under `Connection/` and later folders, which belongs to M2–M5.
- `AppDelegate` keeps its M0 form until the later milestones give it windows to show. It's ported in M5.
