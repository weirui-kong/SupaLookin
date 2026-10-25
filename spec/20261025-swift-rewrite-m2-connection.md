# Swift rewrite M2: connection

## Summary

Third milestone of [`20261025-swift-rewrite.md`](20261025-swift-rewrite.md). It ports `Connection/`:

- `LKConnectionRequest`
- `LKConnectionManager`: port scanning, Peertalk channels, requests, pushes
- `LKAppsManager`: app discovery and auto-reconnect
- `LKInspectableApp`: typed requests to one app

The wire behavior is unchanged: the same ping-then-request sequence, the same timeouts (0.5 s ping before `LookinRequestTypeApp`, 2 s ping otherwise, 5 s per response), the same tags, the same discard-on-newer-request rule, and the same chunked-response accounting by `dataTotalCount`.

## Concurrency

Peertalk delivers every callback on the main queue (`Lookin_PTChannel` and `Lookin_PTUSBHub` are created with `dispatch_get_main_queue()`). So the whole connection layer runs on the main actor, and LookinShared's non-`Sendable` types never leave it. Where Swift 6 can't see that (a continuation or stream carrying them back to the awaiting main-actor task), they travel in a private `@unchecked Sendable` box, and `LKConnectionManager.swift` imports LookinShared with `@preconcurrency`.

## API shape

| Objective-C | Swift |
|---|---|
| `tryToConnectAllPorts` (one `[Lookin_PTChannel]`, never errors) | `tryToConnectAllPorts() async -> [Lookin_PTChannel]`. All ports are tried at once, and results keep port order, as RAC's `zip` did. |
| `requestWithType:data:channel:` (one `next` per response chunk, then `completed`) | `request(type:data:channel:) -> AsyncThrowingStream<(LookinConnectionResponseAttachment, Lookin_PTChannel), Error>` |
| `LKInspectableApp` requests that answer once | `async throws` methods returning the decoded `data` |
| `fetchHierarchyDetailWithTaskPackages:` and `fetchModificationPatchWithTasks:` (chunked) | Methods with `next` / `failure` / `completion` callbacks, delivered synchronously inside Peertalk's callback (see below) |
| `channelWillEnd`, `didReceivePush` (`RACSubject`) | `PassthroughSubject` |
| `LKAppsManager.inspectingApp` observed with `RACObserve` | `inspectingAppPublisher`, an `LKKVOSubject` publisher. It emits the current value on subscribe and again after each assignment, as KVO did. |
| `didAutoReconnectSucc` (`RACSubject`) | `PassthroughSubject<LKInspectableApp, Never>` |

- **Cold start:** a request still goes out at the moment it's made, not when the result is first awaited.
- **Chunked fetches keep synchronous delivery:** `LKStaticAsyncUpdateManager.sendTasks` cancels the previous fetch and relies on that fetch's completion running synchronously, before the new request is recorded. An async consumer would resume later and finalize the wrong request. So these two fetches keep callbacks rather than a stream.
- **Cancellation:** as with the RAC signals, cancelling the awaiting task doesn't cancel the request. Only `cancelRequest(type:channel:)` does, and it finishes the stream without an error, the way RAC sent `completed`.
- **Timeouts:** `LKConnectionRequest` uses a `Timer` in the main run loop's default mode. That matches `performSelector:afterDelay:`, which also doesn't fire while the run loop is in an event-tracking mode.

## Auto-reconnect

When the inspected app's channel ends, `inspectingApp` becomes `nil`. Every 3 s a lookup starts for an app with an equal `LookinAppInfo`, without waiting for earlier lookups to finish, as RAC's `interval` + `flattenMap` did. The timer stops as soon as any app becomes the inspected app. Lookups still in flight finish and may set it again.

## Verification

- Against the LookinServer demo app in the simulator:
  - the launch window lists the app
  - the hierarchy loads
  - stopping and relaunching the demo reconnects automatically within a few seconds
  - an unsupported server version shows the same error text as the Objective-C app
- Request bookkeeping (tags, discard of older requests of the same type, chunk counting, the completion sent on cancel) needs a live `Lookin_PTChannel`, which Peertalk can't create without a socket. It's checked manually against the demo app.

## Out of scope

- The `LookinPush_*` handling stays as it is: the client declares no accepted push frame types, so `didReceivePush` never fires, as in the Objective-C app.
