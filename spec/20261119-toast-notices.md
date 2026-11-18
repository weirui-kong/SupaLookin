# Toasts at the bottom left, and one alert that becomes a toast

## Summary

Two changes to `SPLKToast` and where it's used:
1. Toasts move to the window's bottom left.
2. "Some layer data failed to transmit." shows as a toast instead of an alert.

`SPLKToast` and its first use are in `20261118-protocol-v2-m12-jailbreak-input.md` ("The first screen capture").

## Position

A toast sits at the bottom left of its window's content view, 16 pt from the left and bottom edges. Everything else about it stays as it was: at most 380 pt wide, one per window, a new one replacing the old, gone after its duration or a click.

## "Some layer data failed to transmit."

Lookin shows this as an alert once a details sync finishes with some items failed, typically because the app's layers changed while it was syncing. It needs no answer, and the rest of the sync landed, so a modal alert interrupts for little.

It now shows as a warning toast for 6 s, with the same title and detail as before:
- "Some layer data failed to transmit."
- "It may be due to changes in the layer structure within the iOS app. You can try reloading the entire structure in Lookin."

`SPLKStaticAsyncUpdateManagerDelegate` gains `detailUpdatePartiallyFailed(_:)` for it, so the window can tell it apart from a failed request.

A request that times out ("Request timeout, layer data transmission failed.") stays an alert: nothing synced, and the user needs to act on it.

## Verification

- **`SupaLookinTests`**: a toast's frame sits at its window's bottom left.
- **By hand**: the reconnect toast of the first Live Control shows at the bottom left.
