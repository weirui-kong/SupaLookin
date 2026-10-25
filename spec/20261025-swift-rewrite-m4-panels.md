# Swift rewrite M4: dashboard, console, measure

## Summary

Fifth milestone of [`20261025-swift-rewrite.md`](20261025-swift-rewrite.md). It ports the panels beside the preview:

- `Dashboard/`: the attribute cards, sections and their pool, every attribute view (numbers, geometry, colors, enums, switches, text, shadow, JSON, constraints, class and relation lists, rows count, open image), the accessory window for hidden sections, the enum registry, and the property/method search
- `Console/`: the console data source, its rows, and the target-selection popover
- `Measure/`: the measure controller, tutorial view and result view

`LKDashboardAttributeView` subclasses are chosen by `LookinAttrType` and identifier exactly as before. They are created from their class (`LKDashboardAttributeView.Type`), so the view initializer is `required`.

## API shape

| Objective-C | Swift |
|---|---|
| `-[LKDashboardViewController modifyAttribute:newValue:]` (`RACSignal`) | `modifyAttribute(_:newValue:) async throws` |
| Attribute views subscribing to the modification's error or next | a `Task` that re-renders on error (`submitModification(_:)`) or after success |
| `LKConsoleDataSource` `submit:`, `submitWithObj:text:`, `makeObjectAsCurrent:` | `async throws` |
| `RACObserve(consoleDataSource, rowItems / currentObject)` | `rowItemsPublisher`, `currentObjectPublisher` |
| `recentObjects` (`RACTwoTuple`) | `[(object: LookinObject, message: String)]` |
| `LKDashboardSearchMethodsDataSource fetchNonArgMethodsListWithClass:` | `async throws` with the same per-class cache |
| `rac_textSignal` + `throttle:` | `textDidChangeNotification` + `prepend` + `debounce`, which matches RAC's throttle (it forwards the latest value once typing pauses) |
| `setDashboardViewController:` overrides | `dashboardViewControllerDidChange()` |

## Behavior that stays

- Sizes, insets, column rules (`numberOfColumnsOccupied`), the horizontal/vertical number styles and their decimals, and the attribute ordering are unchanged.
- `LKDashboardTextControlEditingFlag` still suppresses the second end-editing a reload triggers.
- Frame edits still warn when the iOS app reverts the value.
- The color menu, custom color panel and RGBA/HEX toggle behave as before; aliases are hidden for border and shadow colors.
- Constraint jump buttons: both jump to `firstItem`, as in the Objective-C popover.
- `LKJSONAttributeContentView` never enabled its big-font mode; the Swift view keeps the small font.
- The console's measure of a return row, the clear button, the "Select target object" popover and the sync-target switch are unchanged.
- Measure lines, labels, overlap handling and the scale factor are computed as before.

## Deviations

1. **Inbuilt modification without a setter or a connection.** `modifyInbuiltAttribute:` reported the error and then still sent the modification. The Swift method stops after reporting it.
2. **Console submit without an object.** When the object to submit is `nil`, the Swift data source reports the inner error instead of invoking a method on oid 0.

## Behavior checklist

- [ ] Every attribute card renders and collapses; the accessory window adds and removes sections; the relation help menu and the JSON pop-out window work.
- [ ] Editing each editable type (number, point, size, rect, insets, switch, text, enum, color, custom attributes) applies on the device and re-renders; invalid input reverts.
- [ ] Search: properties reveal their section with the highlight animation; methods list and invoke with the result alert.
- [ ] Constraints: popover contents and jumping to an item.
- [ ] Open Image with Preview opens the image, and the temp file is removed on quit.
- [ ] Console: select target, history, suggestions, submit, clear, "Show in console" from the hierarchy.
- [ ] Measure: hover tutorial, invalid size, result lines and labels, locked and ⌥-held modes.

## Verification

- `SupaLookinNextTests` covers the enum registry and the JSON item flattening.
- The checklist above, item by item.

## Out of scope

- `Export/`, `Read/`, `Preference/`, `Tutorial/`, `About/`, `DanceScript/`, which belong to M5.
