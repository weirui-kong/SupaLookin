# Swift rewrite M3: inspecting an app

## Summary

Fourth milestone of [`20261025-swift-rewrite.md`](20261025-swift-rewrite.md). It ports everything needed to pick an app and inspect it:

- `Launch/`: the launch window and its app tiles
- `Hierarchy/`: the hierarchy data source, its key handling, the outline rows, the event-handler popover, DanceUI attributes
- `Static/`: the static data source, the async screenshot/detail updater, the update task makers, messages, and the static window, view and hierarchy controllers
- `Static/Preview/`: the 2D/3D SceneKit preview, its stage view, nodes and pan gesture
- `Toolbar/`: the toolbar items, the app button, the zoom slider, the apps-list and view-settings popovers

`LKHierarchyItem` isn't ported: nothing in the Objective-C app uses it.

## API shape

| Objective-C | Swift |
|---|---|
| `RACObserve(dataSource, selectedItem / hoveredItem / state / displayingFlatItems / rawHierarchyInfo)` | `selectedItemPublisher`, `hoveredItemPublisher`, `statePublisher`, `displayingFlatItemsPublisher`, `rawHierarchyInfoPublisher` (`LKKVOSubject`) |
| `RACSubject` signals on the data sources and `LKStaticAsyncUpdateManager` | `PassthroughSubject`. `modifyingUpdateProgressSignal` keeps its error path as a `.failure` completion. |
| `RACObserve(staticViewController, showConsole)` | `showConsolePublisher` |
| `isFetchingHierarchy` / `isFetchingDetails` combined with `combineLatest` + `distinctUntilChanged` | the same Combine operators over two `LKKVOSubject` publishers |
| `fetchHierarchyData` and the other single-response requests | `async throws`, awaited in a main-actor `Task` |
| `LKAppMenuManagerDelegate` optional methods | `LKWindowController` overrides plus `supportedAppMenuActions`, so a menu item is enabled exactly when the Objective-C delegate responded to its selector |
| Toolbar item `target` / `action` | `NSToolbarItem.onAction`. A view-based item forwards its action to its control, so the handler receives the button, as `_handleSetting:` did. |
| `deliverOnMainThread` | `receive(on: DispatchQueue.main)`, which also always dispatches asynchronously |

## Behavior that stays

- The toolbar identifiers (`"0"`, `"1"`, … `"19"`), item order, labels, minimum sizes and enabling rules are unchanged.
- The measure button is enabled only while an item is selected; Reload is disabled while the hierarchy is being fetched; App, Console and Fast Mode are disabled while fetching the hierarchy or details.
- Reload turns into a stop button showing `finished / total` while details are syncing.
- The preview keeps its scale and z-interspace limits, its key and gesture handling, and the tutorial tips it shows.
- Quirks kept on purpose: changes to `showOutline` aren't saved to `NSUserDefaults`; `leftLightNode` is assigned the right light; the stage view's second appearance block replaces the first.

## Deviations

These are the only intended differences from the Objective-C app:

1. **Console notification.** `LKStaticViewController` added its `LKAppShowConsoleNotificationName` observer in `viewDidLayout`, so every layout pass added another one and a single "Show in console" submitted the object several times. The Swift controller registers the observer once.
2. **Export compression observer.** `appMenuManagerDidSelectExport` subscribed to `preferredExportCompression` for the rest of the app's life, re-encoding the last exported hierarchy on every later change. The Swift subscription ends when the save panel closes.
3. **Empty hierarchy reply.** If `fetchHierarchyData` completes with a `nil` hierarchy, the Swift app shows the inner error. The Objective-C app reloaded the data source with `nil`.

## Behavior checklist

Checked with both apps against the same iOS app running stock LookinServer:

- [ ] Launch window lists simulator and USB apps, shows the no-app state and the "Can't see your app?" link, and entering an app opens the static window.
- [ ] Hierarchy: expand/collapse (including recursively), search, focus mode and its tip, double-click behavior, right-click menu (copy, hide/show screenshot, export screenshot, copy as PNG at each scale), event-handler popover and its gesture toggle.
- [ ] Preview: 2D/3D, zoom slider and buttons, free rotation, z-interspace, ⌘-quick-select, space-drag, hover and selection highlights, hidden-layer outlines.
- [ ] Toolbar: every item, the app popover (including server-version errors), the view-settings popover, notifications menu, fast mode tip.
- [ ] Reload during detail sync stops the sync; reconnecting after the iOS app restarts.
- [ ] Menu bar: reload, dimension, zoom, interspace, expansion levels, filter, export, open in new window.

## Verification

- `SupaLookinNext` builds under Swift 6 with no errors and no concurrency warnings.
- The checklist above, item by item.

## Out of scope

- `Dashboard/`, `Console/`, `Measure/`, which belong to M4.
