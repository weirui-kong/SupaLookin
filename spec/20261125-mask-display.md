# Showing masks

## Summary

A view's `maskView` and a layer's `mask` never show up in Supa Lookin: SPLKServer walks only `sublayers`, and a mask layer has no superlayer. A new switch in the preview settings popover, next to "Show hidden UIView and CALayer", shows them in both the hierarchy panel and the preview.

`maskView` is covered by the same path as `mask`: setting `view.maskView` makes the view's layer's `mask` the mask view's layer, and `splk_hostView` of that layer is the mask view. Everything below works on `layer.mask` and gets the view information from it the way any other layer does.

## The switch

- **Title**: "Show maskView and mask layer", the item right below "Show hidden UIView and CALayer" in `SPLKMenuPopoverSettingController`.
- **Default**: off.
- **Stored** in `SPLKPreferenceManager` as `showMaskItems`, a `SPLKBOOLMsgAttribute` saved under the `UserDefaults` key `showMaskItems`, like `showHiddenItems`.
- **Takes effect at once**: flipping it reloads the hierarchy already on the Mac, keeping expansion and selection, without fetching the hierarchy again. Like any reload, it ends a search or focus, and outside fast mode it fetches the screenshots again.

When it's off, the hierarchy panel and the preview look exactly as they do today. When it's on, every mask shows as an item:
- **Where**: the last child of the item whose `mask` it is, so it sits above that item's other children in the preview. The mask's own sublayers (the mask view's subviews) show under it as usual.
- **Hierarchy row**: a purple capsule reading `mask` between the class name and the subtitle. It turns white on a selected row and fades with the row in a hidden hierarchy. Searching for `mask` finds mask items, as if the badge were part of the row's text. The items under a mask aren't marked; their indentation shows where they are.
- **Preview**: drawn from its own screenshot, like any other layer. Hidden and zero-alpha rules apply to it as to any item.

Turning it off while a mask item, or something under one, is selected selects the item that owns the mask; for a mask inside a mask, the outermost owner. Search and focus results never include mask items while the switch is off.

## Model

`SPLKDisplayItem` gets:
- `isMask`: `YES` for the item that is another item's mask. Encoded under the key `isMask`; a `.lookin` file without it reads as `NO`.
- `maskItem` (`mask` in Swift): the item's mask, if any, held apart from `subitems`. Encoded under the key `maskItem`. `subitems` is encoded without it, whether or not it's joined.

The Mac side joins `maskItem` to the end of `subitems` while the switch is on and takes it out while it's off. It does this in the hierarchy data source on every reload, and again whenever an item's children are replaced by a reload-children fetch. That's all that changes: expandability, flat items, expansion, search, focus and the preview keep working from `subitems` as they do today.

An exported document keeps the screenshots of every mask the Mac has, shown or not, and opening one restores them.

## Protocol

This is a changed meaning under `20261125-protocol-compatibility.md`: an older Mac would show a mask as a plain child.

- **Schema**: `Node.is_mask = 19`. A mask travels as the last child of its owner, one level deeper, with `is_mask` set. The bridge puts a node with `is_mask` into its parent's `maskItem` and every other node into `subitems`.
- **Capability** `hierarchy.masks`, listed by both ends. SPLKServer sends masks, in `GetHierarchy` and in the children of a reload-children fetch, only when it's enabled; the bridge leaves them out of the messages otherwise. Supa Lookin always lists it, whatever the switch says.
- **Without it on either end**, no masks travel: an older Mac gets the hierarchy it gets today, and against an older SPLKServer the switch has nothing to show.

## SPLKServer

- **Collecting**: `SPLKHierarchyDisplayItemsMaker` makes an item for `layer.mask` after the sublayers, both in the full hierarchy and in `subitemsOfLayer`, and recurses into the mask's own sublayers and its mask.
- **Screenshots**:
  - A mask's host view isn't in a window, so `drawViewHierarchyInRect:afterScreenUpdates:` draws nothing for it. A layer that isn't in a window is drawn with `renderInContext:`, in both the solo and the group screenshot.
  - The owner's own screenshots don't change: they already show the masked result.
  - A shown mask makes its owner expandable, and an expanded item draws its solo screenshot. So an owner with a mask but no sublayers gets its group screenshot as its solo screenshot, instead of none.
- **Ivar traces**: `SPLKTraceManager` walks masks too, so a mask stored in an ivar shows its ivar name.
- **Change detection**: `SPLKUIMonitor`'s signature covers masks too, so adding, removing or moving one refreshes the hierarchy.
- **Device-side export**: the `.lookin` file exported on the device includes masks.

## MCP

The hierarchy, search and detail tools always include masks, whatever the switch says, and mark them with `"mask": true`. A tool given a hidden mask's oid finds it too.

## Strings

| Key | en | zh-Hans |
|---|---|---|
| `Show maskView and mask layer` | Show maskView and mask layer | 显示 maskView 和 mask 图层 |

## SPLK Chat

Discover gets an "Inspector Cases" section with a Masks screen:
- a `maskView` with two subviews;
- a `CAShapeLayer` mask on an image view, which has no sublayers;
- a `CAGradientLayer` mask fading a label;
- a mask with its own mask;
- a mask a switch adds and removes.

Launching the app with `-SPLKChatScreen masks` opens that screen.

## Verification

- **`SPLKModelBridgeTests`**: a tree with a mask round-trips, with the mask in `maskItem`, not `subitems`; without `includesMasks`, no mask travels.
- **`SupaLookinTests`**:
  - the switch on puts the mask last in `subitems`, and off takes it out;
  - fetched children put their mask in `maskItem`;
  - turning it off with a mask selected selects its owner;
  - a document keeps the mask apart from `subitems`.
- **Live** (`SPLKMaskLiveTests`, with `TEST_RUNNER_SPLK_MASK_LIVE=1`), against SPLK Chat on the Masks screen, on a device or a simulator:
  - every case arrives with its masks where they belong;
  - the screenshots of a mask view, a shape mask, and the solo screenshot of a mask's owner with no sublayers aren't blank;
  - the switch adds and removes the masks from the data source's items, and searching for `mask` finds them;
  - removing a mask in the app and fetching again leaves it out.
- **By hand**: the switch shows and hides masks in both panels at once, and an MCP hierarchy call lists masks with the switch off.
