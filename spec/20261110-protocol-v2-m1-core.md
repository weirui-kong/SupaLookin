# Protocol v2 M1: protocol core

## Summary

M1 builds `SPLKProtocol`, the Swift target that both ends of protocol v2 (`20261109-protocol-v2.md`) share: the schema, framing, transports, the per-connection RPC machinery, and the client and host sessions with their handshake. Nothing uses it yet. It isn't part of the `SPLKServer` product, and the app and server keep speaking v1 until M2 and M3 ship together.

## Package

- New dependency: `https://github.com/apple/swift-protobuf`, from `1.39.0`. That release requires Swift tools 6.2, and the code its generator writes uses Swift 6.2 syntax, so building the package needs Xcode 26 or later. `README.md` states this once SPLKServer depends on it in M2.
- `Package.swift` moves to `swift-tools-version:6.2` to match, so new Swift targets build in the Swift 6 language mode. `SPLKServerSwift`, which holds upstream's Swift, stays in Swift 5 mode.
- New targets:

  | Target | Kind | Depends on |
  |---|---|---|
  | `SPLKProtocol` | Swift library target, macOS 14 / iOS-family 13 | `SwiftProtobuf` |
  | `SPLKProtocolTests` | Swift Testing test target | `SPLKProtocol` |

- Layout:

  ```
  Sources/SPLKProtocol/
    Schema/splk.proto
    Generated/splk.pb.swift
    Framing/
    Transport/
    RPC/
    Session/
  Tests/SPLKProtocolTests/
  Scripts/generate-protocol.sh
  ```

## Schema

- `Schema/splk.proto` is the schema of `20261109-protocol-v2.md`, with `option swift_prefix = "SPLKV2";` so generated types follow the `SPLK` prefix rule (`SPLKV2Envelope`, `SPLKV2Node`).
- `Scripts/generate-protocol.sh`:
  - runs `protoc` with `protoc-gen-swift` and `Visibility=Public` into `Generated/`;
  - refuses to run unless `protoc-gen-swift --version` reports 1.39.0, since generated code must match the runtime the package pins.

  Generated code is committed and never edited by hand.
- **Flat hierarchies**: `HierarchySnapshot.nodes` and `NodeDetail.children` list nodes in pre-order with `Node.depth`, as amended in the v2 spec. Decoding uses swift-protobuf's default options; no message nests more than a dozen levels.

## Framing

The 12-byte header of the v2 spec. This milestone fixes the meaning of flag bit 0:

- **Bit 0 set** means the message continues in the next frame.
  - A message longer than one frame's 16 MiB payload is sent as consecutive frames: every one but the last has the bit set.
  - Fragments of one message are never interleaved with another message's frames on the same connection.
- **Limits**:
  - A message may total at most 256 MiB.
  - A frame or message over its limit, a bad magic, an unknown format, an unknown kind or any other set flag closes the connection.
- **Encoding**: a sender writes all frames of a message with one write, so concurrent senders on one connection can't interleave fragments.
- **Decoding**: the decoder is incremental. It accepts bytes in arbitrary pieces and yields complete messages as `(kind, payload)`.

## Transports

`SPLKByteStream` is the one abstraction above the socket:
- `incoming`: an `AsyncThrowingStream<Data, Error>` of received bytes, finishing when the peer closes;
- `send(_:) async throws`;
- `close()`.

Three implementations:

| Implementation | Used for |
|---|---|
| `SPLKNetworkByteStream` (`NWConnection`) | the host's accepted connections; the Mac's simulator connections to `127.0.0.1` |
| `SPLKDispatchIOByteStream` (a connected file descriptor read and written through `DispatchIO`) | the Mac's usbmux connections, whose `SPLK_PTUSBHub` gives a connected `dispatch_io_t` |
| `SPLKMemoryByteStream.pair()` | tests |

Helpers:
- `SPLKNetworkByteStream.connect(host:port:timeout:)` opens a client connection.
- `SPLKListener` wraps `NWListener` on `127.0.0.1`:
  - it binds the first free port of a given range (v1's port-scan behavior), or a system-assigned port for tests;
  - it hands each accepted connection over as a byte stream.

## RPC

`SPLKRPCConnection` (an actor) runs the envelope protocol over one framed byte stream.

**Calls it sends:**
- **unary**: returns the `SPLKV2Response`.
- **stream**: returns an `AsyncThrowingStream<SPLKV2StreamItem, Error>`, which finishes on `StreamEnd`.
- **one-way**: returns once written. Its failure, if any, arrives on the session's one-way error stream.

A non-OK status, from a `Response` or a `StreamEnd`, is thrown as `SPLKStatusError` (code, reason, title, detail).

**Requests it receives** go to an `SPLKRequestHandler`:
- The handler answers with a response result, a stream of items, or nothing for one-way requests.
- Thrown `SPLKStatusError`s become that status. Any other error becomes `INTERNAL`.
- A request whose `call` is unset is answered `UNIMPLEMENTED` before reaching the handler. This is how a newer peer's methods arrive.

**Deadlines:**
- `deadline_ms` 0 means 5 s.
- The receiving side cancels the handler past the deadline and answers `DEADLINE_EXCEEDED`.
- The calling side fails the call with `DEADLINE_EXCEEDED` if nothing arrives within the deadline plus 1 s.
- Both restart a stream's deadline on every item.

**Cancellation:**
- Cancelling the task awaiting a unary call, or terminating a stream's consumption, sends `Cancel{id}`.
- The receiving side cancels the handler and ends a stream with `StreamEnd` `CANCELLED`.
- Messages for ids no longer pending are ignored.

**Request ids** come from an allocator the session passes in, so ids stay unique across a session's connections.

**Closing**: closing the connection fails everything pending on it with `UNAVAILABLE`. That code is local only: it is never sent and never part of `Status.Code`.

## Sessions

**`SPLKClientSession`** opens a session to one host:
1. It connects `CONTROL` and sends `ClientHello`, then waits for `ServerHello`. A non-OK status, a different generation, or no `ServerHello` within the handshake timeout fails the session. The timeout defaults to 2 s; discovery passes its own.
2. It connects `BULK` with the returned session id and completes the same handshake.
3. It routes each call by method to its channel, as in the v2 Methods table.
4. It refuses to send a call whose capability the host didn't list, failing it locally with `UNIMPLEMENTED`.
5. It sends a `Heartbeat` on `CONTROL` every 2 s.

It exposes the host's `ServerHello`, the negotiated capabilities, and a `closed` signal.

**`SPLKHost`** accepts connections from an `SPLKListener`, or from any byte streams handed to it:
- **`CONTROL` hello**: checks the generation, creates a session and answers with its id. Any previous session is closed first.
- **`BULK` hello**: attaches the connection to the session with that id, or answers `NOT_FOUND`.
- **`VIDEO` hello**: answered `UNIMPLEMENTED` until a milestone adds in-app video.
- **Liveness**: a session not heard from on `CONTROL` for 6 s is closed.

Every request goes to the host's `SPLKRequestHandler` with a context naming the session and channel.

Capability names, the method-to-channel and method-to-capability tables, and the generation constant (2) live in `SPLKProtocol`, so both ends read one definition.

## Tests

`SPLKProtocolTests`, run with `swift test` locally and by `ci.yml` on every push:

- **Framing**:
  - round trips at frame and message boundaries;
  - fragmentation of a message over 16 MiB;
  - bytes delivered one at a time;
  - each rejection case.
- **Decoding** a flat hierarchy 5,000 levels deep on a Swift concurrency thread.
- **Handshake**:
  - success;
  - generation mismatch;
  - `BULK` with an unknown session id;
  - timeout;
  - a second `CONTROL` replacing the first session.
- **Calls**:
  - unary, stream and one-way;
  - a one-way failure reaching the error stream;
  - status errors;
  - a non-status error becoming `INTERNAL`;
  - an unset `call` answered `UNIMPLEMENTED`;
  - a call refused locally for a missing capability.
- **Concurrency**:
  - two concurrent unary calls of the same method both complete; nothing is discarded;
  - a slow stream on `BULK` doesn't delay a unary call on `CONTROL`.
- **Deadlines**: on both sides, including a stream's deadline restarting per item.
- **Cancellation**: of a unary call and of a stream, seen by the handler.
- **Liveness**: heartbeats keep a session alive; their absence closes it.
- **Transports**: the same call suite over `SPLKNetworkByteStream` on loopback and over `SPLKDispatchIOByteStream` on a socket pair.

## Out of scope

- The server runtime, converters and the Mac integration (M2, M3).
- Video packets beyond framing.
- Leases, events and input (M4 onward). Their messages exist in the schema; only the mechanisms above are built.
