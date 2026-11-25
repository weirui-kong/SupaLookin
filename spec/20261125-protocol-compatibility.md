# Compatibility between Supa Lookin and SPLKServer versions

## Summary

A Mac and a phone often run different releases: an app built weeks ago with an older SPLKServer, or a newer SPLKServer against a Supa Lookin that hasn't updated yet. `20261109-protocol-v2.md` already says features are negotiated through capabilities, and that a feature is on only when both sides list its capability. Today only the Mac acts on that: SPLKServer never keeps what the Mac listed, so it has no way to hold back data an older Mac would misread.

This spec closes that gap and sets one rule for each kind of change, so each new feature spec only has to say which kind it is.

## Enabled capabilities on both ends

- **The Mac** lists in `ClientHello.capabilities` every capability it understands, including the ones that only change what the server sends.
- **SPLKServer** lists in `ServerHello.capabilities` every capability it offers, as today.
- **Both ends** keep the intersection, the session's *enabled capabilities*. The Mac already does (`SPLKClientSession.capabilities`).
  - `SPLKHost` stores it on the session when the `CONTROL` hello arrives. `BULK` connections use their session's set.
  - `SPLKRequestContext` gets `capabilities: Set<String>`, so a request handler can check it.

## Kinds of change

| Kind | Example | What it takes |
|---|---|---|
| **Safe to ignore**: an older peer can drop the new data without misreading anything | a new field on `NodeDetail`, a new attribute | Add the field. A reader that doesn't find it uses the default. No capability. |
| **New call**: a new method or event topic | `WaitForIdle` | SPLKServer lists a capability. The Mac checks it before calling (`requiredCapabilities`), and the feature's spec says how the Mac behaves without it. |
| **Changed meaning**: data an older peer would misread | a node that isn't a plain child; an enum value an older reader would mishandle | A capability both ends list. SPLKServer sends the new data only when the capability is enabled and keeps the old output otherwise. |
| **Can't be bridged** | a new framing | Bump the protocol generation. The last resort. |

When it's unclear whether data is safe to ignore, it's a changed meaning.

## Rules

- **Gate on capabilities, never on versions.** `client_version` and `server_version` are only for display and for the outdated-server hint.
- **Capability names** are `<area>.<feature>` in lower case (`hierarchy.masks`). Each one is a constant in `SPLKCapability`, with a comment naming the spec that added it. A name is never renamed or reused.
- **One capability per feature.** Not one per release, and not one for a group of features.
- **Schema**: field numbers are never reused or renumbered, and removed fields become `reserved`, as `20261109-protocol-v2.md` says. A reader treats an unknown enum value as unspecified.
- **Old paths stay** as long as they're cheap to keep. Dropping one means no longer listing its capability. The peer then falls back to its own path without it.
- **Documents**: a new `NSCoding` key needs a default for files written without it. `SPLK_DOCUMENT_VERSION` changes only when an older app can't read a new file correctly.
- **MCP output**: new JSON keys only. Existing keys keep their meaning.

## Each feature spec

A spec that touches the protocol says:
- which kind its change is;
- its capability, if it needs one;
- what each end does when the other doesn't list it.

## Verification

- **`SPLKProtocol` tests**: in an in-memory session, the server's request context holds the intersection of the two hellos, on both `CONTROL` and `BULK`.
- **Each changed-meaning feature** adds a test showing that a client without its capability gets the old output.
