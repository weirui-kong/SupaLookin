# Expanding a set number of levels

## Summary

"Expand recursively" opens everything under an item, which in a deep tree buries the part a person wanted to see. Three new menu items below it expand only the first few levels:
- "Expand 3 levels"
- "Expand 5 levels"
- "Expand 10 levels"

## Where

Both menus that have "Expand recursively" get the three items right below it, in that order:
- **The hierarchy panel's context menu**: for any expandable item, as "Expand recursively" is.
- **The preview's context menu**: when the item is expandable and collapsed, as "Expand recursively" is.

## What "N levels" opens

Counting the item as level 0, it expands every expandable item at levels 0 to N − 1, so its descendants down to level N show. Items deeper than that keep their state: one already expanded stays expanded.

Like "Expand recursively", it leaves alone items that prefer to be collapsed (`preferToBeCollapsed`, such as system containers), unless the item clicked prefers that itself, in which case it opens those too.

## Strings

| Key | en | zh-Hans |
|---|---|---|
| `Expand %d levels` | Expand %d levels | 展开 %d 层 |

## Verification

- **`SupaLookinTests`**, on a tree four levels deep:
  - 3 levels expands levels 0 to 2 and leaves level 3 as it was;
  - an item that prefers to be collapsed stays collapsed, unless it's the one clicked.
- **By hand**: both menus show the three items below "Expand recursively", and each opens that many levels.
