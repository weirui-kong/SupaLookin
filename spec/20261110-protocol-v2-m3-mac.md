# Protocol v2 M3: Mac

## Summary

M3 moves Supa Lookin from protocol v1 to v2 and removes v1 from the repository. It ships in one release with M2 (`20261110-protocol-v2-m2-server.md`).

The window, dashboard, console and MCP tools keep their code. Only the connection layer below `SPLKAppsManager` and `SPLKInspectableApp` changes, and those two keep their interfaces.

## Package and project

- The app links the `SPLKModelBridge` product in addition to `SPLKServer`.
- Two classes are deleted. They existed only to wrap v1 payloads and were never written into documents:
  - `SPLKConnectionAttachment`
  - `SPLKConnectionResponseAttachment`
- Peertalk is reduced to what usbmux needs:
  - `SPLK_PTUSBHub` and `SPLK_PTPrivate.h` stay.
  - `SPLK_PTChannel`, `SPLK_PTProtocol` and `Peertalk.h` are deleted.
- **Version constants**: `SPLKDefines.h` drops `SPLK_SERVER_VERSION`, `SPLK_CLIENT_VERSION`, `SPLK_SUPPORTED_SERVER_MIN` and `SPLK_SUPPORTED_SERVER_MAX`. One new constant replaces them for documents:
  - `SPLK_DOCUMENT_VERSION = 1`
  - Converted hierarchies and exported files carry it in `serverVersion`.
  - `verifyHierarchyFile:` accepts exactly it, and its messages quote it.
- `SPLKPreferenceManager` stores `SPLKProtocolInfo.generation` under its previous-client-version key, where it stored `SPLK_CLIENT_VERSION`.

## Connections

`SPLKConnectionManager` is rewritten on `SPLKProtocol`.

**Ports**:
- The simulator ports, 47264–47269.
- Per attached USB device, 47275–47279. Devices are tracked through `SPLK_PTUSBHub`'s attach and detach notifications, as before.

**Connecting**:
- A simulator port: `SPLKNetworkByteStream.connect(host: "127.0.0.1", …)`.
- A USB port: `SPLK_PTUSBHub.connectToDevice:port:onStart:onEnd:`. The `dispatch_io_t` it returns becomes an `SPLKDispatchIOByteStream`.

**Sessions**:
- Each port keeps at most one live `SPLKDeviceSession`.
- Discovery connects only the ports without one, all at once, with a 0.5 s handshake timeout (v1's `App` request timeout).
- An existing session is never reconnected by discovery. A second `CONTROL` connection would replace it on the host, just as v1 reused connected channels.

**Handshake outcomes become the errors the launch view already shows**:

| Outcome | Error |
|---|---|
| connection refused | no app on that port |
| connected, but no `ServerHello` (a v1 SPLKServer) | `SPLKErrCode_ServerVersionTooLow` |
| `ServerHello` with a lower generation | `SPLKErrCode_ServerVersionTooLow` |
| `ServerHello` with a higher generation | `SPLKErrCode_ServerVersionTooHigh` |

For this, `SPLKClientSession` checks `protocol_generation` before the hello's status. A host that rejects another generation still reports its own, so the client can tell whether it's older or newer.

## SPLKDeviceSession

`SPLKDeviceSession` is an actor wrapping one `SPLKClientSession`:
- It offers one async method per v2 method, taking and returning the `SPLK*` models through `SPLKModelBridge`.
- `FetchDetails` and `FetchModificationPatch` return streams.
- It tells the client name, `Supa Lookin`, and version, the app's `MARKETING_VERSION`, in `ClientHello`.
- It converts `HierarchySnapshot` with `serverVersion = SPLK_DOCUMENT_VERSION` and `appInfo.serverReadableVersion = ServerHello.server_version`.

**Errors** become the `NSError`s v1 produced, so every message the UI shows stays the same:

| Status | Error |
|---|---|
| `NOT_FOUND` / `object_deallocated` | `SPLKError.objNotFound` |
| `INTERNAL` / `inner` | `SPLKError.inner` |
| `DEADLINE_EXCEEDED` | `SPLKErrCode_Timeout`, "Request timeout", `SPLKError.timeoutText` |
| `FAILED_PRECONDITION` / `app_in_background` | `SPLKErrCode_PingFailForBackgroundState` with v1's text |
| local `UNAVAILABLE` | `SPLKError.noConnect` |
| any other | `SPLKErrorDomain`, `SPLKErrCode_Default`, with the status's `title` and `detail` |

## SPLKInspectableApp and SPLKAppsManager

`SPLKInspectableApp` holds an `SPLKDeviceSession` where it held a channel. Its methods keep their signatures and behavior:

- **The window's requests keep v1's "newest wins" rule.**
  - A new request of a method still in flight cancels the older one.
  - The older one fails with v1's `SPLKErrCode_Discard` error.
  - The rule lives here, for the window's requests only. The MCP tools read through `SPLKStaticHierarchyDataSource` and `SPLKAppsManager`, as before.
- **Cancelling the hierarchy details fetch** cancels its stream, and the caller gets `completion`, as v1's `cancelRequest` did.

`SPLKAppsManager`:
- `fetchAppInfos` sends `GetAppInfo` with `need_images` and the cached identifiers to every discovered session, as v1 sent `App`.
- The reconnect loop and `inspectingApp` handling stay. A session closing takes the place of v1's `channelWillEnd`.

## Removed

- `SPLKConnectionRequest.swift`.
- The ping-per-request logic and its version check.
- `checkServerVersion`.
- The `-1` / `100` handling, already gone since `20261109-splk-server.md`.

## Documentation

`README.md` says that building SPLKServer needs Xcode 26 or later.

## Verification

- `SupaLookinTests` pass, with the tests that referenced the removed constants updated to `SPLK_DOCUMENT_VERSION` and the protocol generation.
- `SPLKModelBridge` round trips (M2) cover the Mac direction.
- **Against the e2e demo on the simulator** and against a USB device, every row of the v2 Methods table works from the window:
  - the hierarchy loads, and screenshots render;
  - inbuilt and custom attribute edits apply;
  - the console invokes methods;
  - selector search works;
  - image views open;
  - gesture recognizers toggle.
- The MCP read-only tools work while the window syncs.
- **An app with SPLKServer 1.0.15 (v1)** shows the "version too low" message instead of hanging.
- **A details fetch over 20 MB** doesn't delay a concurrent `GetObject` by more than 50 ms.
- `.supalookin` and `.lookin` documents keep opening, and new exports reopen.

## Out of scope

Leases, events, Live Control and Takeover (M4 onward).

## Update: implementation notes

- **`SPLKDeviceSession` is a main-actor class, not an actor.** The app target isolates to the main actor by default, and the window consumes the `SPLK*` models on it. The network work already runs in `SPLKClientSession`'s actors, so the device session only converts results on the actor that uses them.
- **App icons.** v2 hierarchies don't carry the app icon v1's did. `fetchHierarchyData` fills it from the `SPLKAppInfo` discovery fetched, as the reconnect path already copied it.
- **Detail batches.** `fetchHierarchyDetail` hands each streamed detail to `next` as a one-element array, the shape v1's batches had.
- **Public headers.** Swift targets of the package see the Objective-C headers through the Clang importer, which doesn't get the package's C macros. So the headers under `include/` have no compile gates; their implementations keep them. The app's `-Xcc -DSHOULD_COMPILE_SPLK_SHARED=1` is removed.
- **v1 constants.** The request type, push and parameter constants in `SPLKDefines.h`, used only by v1's wire format, are removed. `SPLKStringFlag_VoidReturn` stays, for the window's invoke result.
- **Verified** on the simulator: discovery, hierarchy sync, details, attributes and screenshots through the MCP tools, plus a silent server on a scanned port (a v1 SPLKServer's behavior) reported as "version too low".
- **Not verified**: a USB device, and the 20 MB transfer timing against a live app. The latter is covered over loopback by `SPLKProtocolTests`.
