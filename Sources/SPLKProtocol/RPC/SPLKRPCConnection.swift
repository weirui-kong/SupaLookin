//
//  SPLKRPCConnection.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SHARED

import Foundation
import SwiftProtobuf

public struct SPLKRequestContext: Sendable {
    public let sessionID: Data
    public let channel: SPLKV2ChannelRole
    public let requestID: UInt64
    public let clientVersion: String
}

public enum SPLKHandlerResult: Sendable {
    case response(SPLKV2Response.OneOf_Result?)
    case stream(AsyncThrowingStream<SPLKV2StreamItem, Error>)
}

public protocol SPLKRequestHandler: Sendable {
    func handle(_ request: SPLKV2Request, context: SPLKRequestContext) async throws -> SPLKHandlerResult
    func sessionDidEnd(_ sessionID: Data) async
}

extension SPLKRequestHandler {
    public func sessionDidEnd(_ sessionID: Data) async {}
}

public struct SPLKOnewayFailure: Sendable {
    public let requestID: UInt64
    public let error: SPLKStatusError
}

// Runs the envelope protocol over one connection: the hello exchange first, then calls in both directions.
public actor SPLKRPCConnection {

    private enum Phase {
        case handshake
        case running
        case closed
    }

    private final class UnaryCall {
        var result: Result<SPLKV2Response, Error>?
        var continuation: CheckedContinuation<SPLKV2Response, Error>?
        var watchdog: SPLKWatchdog?

        func complete(_ result: Result<SPLKV2Response, Error>) {
            watchdog?.cancel()
            if let continuation {
                self.continuation = nil
                continuation.resume(with: result)
            } else if self.result == nil {
                self.result = result
            }
        }
    }

    private final class StreamCall {
        let continuation: AsyncThrowingStream<SPLKV2StreamItem, Error>.Continuation
        var watchdog: SPLKWatchdog?

        init(continuation: AsyncThrowingStream<SPLKV2StreamItem, Error>.Continuation) {
            self.continuation = continuation
        }
    }

    private final class InboundCall {
        enum Termination {
            case cancelledByPeer
            case deadlineExceeded
        }

        var task: Task<Void, Never>?
        var watchdog: SPLKWatchdog?
        var termination: Termination?
        var isStreaming = false
    }

    private let stream: any SPLKByteStream
    private var phase = Phase.handshake
    private var readTask: Task<Void, Never>?
    private var bufferedFrames: [Data] = []
    private var helloWaiter: CheckedContinuation<Data, Error>?
    private var helloWatchdog: SPLKWatchdog?

    private var handler: (any SPLKRequestHandler)?
    private var sessionID = Data()
    private var channel = SPLKV2ChannelRole.unspecified
    private var clientVersion = ""
    private var activityObserver: (@Sendable () -> Void)?
    private var onewayFailureObserver: (@Sendable (SPLKOnewayFailure) -> Void)?

    private var unaryCalls: [UInt64: UnaryCall] = [:]
    private var streamCalls: [UInt64: StreamCall] = [:]
    private var inboundCalls: [UInt64: InboundCall] = [:]
    private var recentOnewayIDs: [UInt64] = []
    private var closeWaiters: [CheckedContinuation<Void, Never>] = []

    public init(stream: any SPLKByteStream) {
        self.stream = stream
    }

    public func start() {
        guard readTask == nil, phase != .closed else { return }
        readTask = Task { [stream] in
            var decoder = SPLKFrameDecoder()
            do {
                for try await chunk in stream.incoming {
                    for message in try decoder.append(chunk) {
                        self.receiveFrame(message)
                    }
                }
            } catch {}
            self.close()
        }
    }

    // MARK: - Hello

    public func sendHello(_ message: some SwiftProtobuf.Message) async throws {
        try await write(try message.serializedData())
    }

    public func receiveHello(timeout: TimeInterval) async throws -> Data {
        guard phase == .handshake else {
            throw SPLKTransportError.closed
        }
        if !bufferedFrames.isEmpty {
            return bufferedFrames.removeFirst()
        }
        return try await withCheckedThrowingContinuation { continuation in
            helloWaiter = continuation
            helloWatchdog = SPLKWatchdog(timeout: timeout) { [weak self] in
                Task { await self?.failHelloWaiter(SPLKTransportError.timedOut) }
            }
        }
    }

    private func failHelloWaiter(_ error: Error) {
        helloWatchdog?.cancel()
        helloWatchdog = nil
        helloWaiter?.resume(throwing: error)
        helloWaiter = nil
    }

    public func startDispatching(
        handler: (any SPLKRequestHandler)?,
        sessionID: Data,
        channel: SPLKV2ChannelRole,
        clientVersion: String = "",
        activity: (@Sendable () -> Void)? = nil,
        onewayFailure: (@Sendable (SPLKOnewayFailure) -> Void)? = nil
    ) {
        guard phase == .handshake else { return }
        self.handler = handler
        self.sessionID = sessionID
        self.channel = channel
        self.clientVersion = clientVersion
        activityObserver = activity
        onewayFailureObserver = onewayFailure
        phase = .running
        let early = bufferedFrames
        bufferedFrames = []
        early.forEach(dispatchEnvelope)
    }

    // MARK: - Outgoing calls

    public func unary(_ request: SPLKV2Request, id: UInt64) async throws -> SPLKV2Response {
        guard phase == .running else {
            throw SPLKStatusError(.unavailable)
        }
        let call = UnaryCall()
        unaryCalls[id] = call
        call.watchdog = SPLKWatchdog(timeout: Self.deadline(of: request) + 1) { [weak self] in
            Task { await self?.expireUnary(id) }
        }
        do {
            try await send(.request(request), id: id)
        } catch {
            unaryCalls[id] = nil
            call.watchdog?.cancel()
            throw SPLKStatusError(.unavailable)
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if let result = call.result {
                    continuation.resume(with: result)
                } else {
                    call.continuation = continuation
                }
            }
        } onCancel: {
            Task { await self.abandonUnary(id, error: SPLKStatusError(.cancelled)) }
        }
    }

    public func stream(_ request: SPLKV2Request, id: UInt64) async throws -> AsyncThrowingStream<SPLKV2StreamItem, Error> {
        guard phase == .running else {
            throw SPLKStatusError(.unavailable)
        }
        let (items, continuation) = AsyncThrowingStream<SPLKV2StreamItem, Error>.makeStream()
        let call = StreamCall(continuation: continuation)
        streamCalls[id] = call
        call.watchdog = SPLKWatchdog(timeout: Self.deadline(of: request) + 1) { [weak self] in
            Task { await self?.abandonStream(id, error: SPLKStatusError(.deadlineExceeded)) }
        }
        continuation.onTermination = { [weak self] termination in
            if case .cancelled = termination {
                Task { await self?.abandonStream(id, error: nil) }
            }
        }
        do {
            try await send(.request(request), id: id)
        } catch {
            streamCalls[id] = nil
            call.watchdog?.cancel()
            throw SPLKStatusError(.unavailable)
        }
        return items
    }

    public func oneway(_ request: SPLKV2Request, id: UInt64) async throws {
        guard phase == .running else {
            throw SPLKStatusError(.unavailable)
        }
        recentOnewayIDs.append(id)
        if recentOnewayIDs.count > 1024 {
            recentOnewayIDs.removeFirst(recentOnewayIDs.count - 1024)
        }
        var request = request
        request.oneway = true
        do {
            try await send(.request(request), id: id)
        } catch {
            throw SPLKStatusError(.unavailable)
        }
    }

    public func sendHeartbeat() async throws {
        try await send(.heartbeat(SPLKV2Heartbeat()), id: 0)
    }

    private func expireUnary(_ id: UInt64) {
        abandonUnary(id, error: SPLKStatusError(.deadlineExceeded))
    }

    private func abandonUnary(_ id: UInt64, error: SPLKStatusError) {
        guard let call = unaryCalls.removeValue(forKey: id) else { return }
        call.complete(.failure(error))
        sendCancel(id)
    }

    // `error` is nil when the consumer stopped listening; the stream has already terminated then.
    private func abandonStream(_ id: UInt64, error: SPLKStatusError?) {
        guard let call = streamCalls.removeValue(forKey: id) else { return }
        call.watchdog?.cancel()
        if let error {
            call.continuation.finish(throwing: error)
        }
        sendCancel(id)
    }

    private func sendCancel(_ id: UInt64) {
        guard phase == .running else { return }
        Task { try? await self.send(.cancel(SPLKV2Cancel()), id: id) }
    }

    // MARK: - Incoming frames

    private func receiveFrame(_ message: SPLKFrameMessage) {
        guard message.kind == .envelope else {
            close()
            return
        }
        switch phase {
        case .handshake:
            if let helloWaiter {
                self.helloWaiter = nil
                helloWatchdog?.cancel()
                helloWatchdog = nil
                helloWaiter.resume(returning: message.payload)
            } else {
                bufferedFrames.append(message.payload)
            }
        case .running:
            dispatchEnvelope(message.payload)
        case .closed:
            break
        }
    }

    private func dispatchEnvelope(_ payload: Data) {
        guard let envelope = try? SPLKV2Envelope(serializedBytes: payload) else {
            close()
            return
        }
        activityObserver?()
        let id = envelope.id
        switch envelope.body {
        case .request(let request):
            receiveRequest(request, id: id)
        case .response(let response):
            receiveResponse(response, id: id)
        case .streamItem(let item):
            if let call = streamCalls[id] {
                call.watchdog?.touch()
                call.continuation.yield(item)
            }
        case .streamEnd(let end):
            if let call = streamCalls.removeValue(forKey: id) {
                call.watchdog?.cancel()
                call.continuation.finish(throwing: SPLKStatusError(status: end.status))
            }
        case .cancel:
            if let call = inboundCalls[id] {
                call.termination = call.termination ?? .cancelledByPeer
                call.task?.cancel()
            }
        case .event, .heartbeat, nil:
            break
        }
    }

    private func receiveResponse(_ response: SPLKV2Response, id: UInt64) {
        if let call = unaryCalls.removeValue(forKey: id) {
            if let error = SPLKStatusError(status: response.status) {
                call.complete(.failure(error))
            } else {
                call.complete(.success(response))
            }
        } else if recentOnewayIDs.contains(id), let error = SPLKStatusError(status: response.status) {
            onewayFailureObserver?(SPLKOnewayFailure(requestID: id, error: error))
        }
    }

    // MARK: - Incoming calls

    private func receiveRequest(_ request: SPLKV2Request, id: UInt64) {
        guard request.call != nil, let handler else {
            let error = SPLKStatusError(.unimplemented)
            Task { try? await self.send(.response(Self.response(status: error.status)), id: id) }
            return
        }
        let call = InboundCall()
        inboundCalls[id] = call
        call.watchdog = SPLKWatchdog(timeout: Self.deadline(of: request)) { [weak self] in
            Task { await self?.expireInbound(id) }
        }
        let context = SPLKRequestContext(sessionID: sessionID, channel: channel, requestID: id, clientVersion: clientVersion)
        call.task = Task {
            await self.runInbound(request, id: id, call: call, handler: handler, context: context)
        }
    }

    private func expireInbound(_ id: UInt64) {
        guard let call = inboundCalls[id] else { return }
        call.termination = call.termination ?? .deadlineExceeded
        call.task?.cancel()
    }

    private func runInbound(_ request: SPLKV2Request, id: UInt64, call: InboundCall, handler: any SPLKRequestHandler, context: SPLKRequestContext) async {
        defer {
            call.watchdog?.cancel()
            inboundCalls[id] = nil
        }
        var failure: SPLKStatusError?
        do {
            let result = try await handler.handle(request, context: context)
            switch result {
            case .response(let value):
                if let termination = Self.status(of: call) {
                    failure = termination
                } else if !request.oneway {
                    var response = SPLKV2Response()
                    response.result = value
                    try await send(.response(response), id: id)
                }
            case .stream(let items):
                call.isStreaming = true
                for try await item in items {
                    if Self.status(of: call) != nil {
                        break
                    }
                    call.watchdog?.touch()
                    try await send(.streamItem(item), id: id)
                }
                failure = Self.status(of: call)
                if failure == nil {
                    try await send(.streamEnd(SPLKV2StreamEnd()), id: id)
                }
            }
        } catch {
            failure = Self.status(of: call) ?? SPLKStatusError.from(error)
        }
        guard let failure, phase == .running else { return }
        if call.isStreaming {
            var end = SPLKV2StreamEnd()
            end.status = failure.status
            try? await send(.streamEnd(end), id: id)
        } else {
            try? await send(.response(Self.response(status: failure.status)), id: id)
        }
    }

    private static func status(of call: InboundCall) -> SPLKStatusError? {
        switch call.termination {
        case .cancelledByPeer: return SPLKStatusError(.cancelled)
        case .deadlineExceeded: return SPLKStatusError(.deadlineExceeded)
        case nil: return nil
        }
    }

    private static func response(status: SPLKV2Status) -> SPLKV2Response {
        var response = SPLKV2Response()
        response.status = status
        return response
    }

    // MARK: - Writing and closing

    private func send(_ body: SPLKV2Envelope.OneOf_Body, id: UInt64) async throws {
        var envelope = SPLKV2Envelope()
        envelope.id = id
        envelope.body = body
        try await write(try envelope.serializedData())
    }

    private func write(_ payload: Data) async throws {
        guard phase != .closed else {
            throw SPLKTransportError.closed
        }
        let data = try SPLKFraming.encode(SPLKFrameMessage(kind: .envelope, payload: payload))
        do {
            try await stream.send(data)
        } catch {
            close()
            throw error
        }
    }

    public func close() {
        guard phase != .closed else { return }
        phase = .closed
        stream.close()
        readTask?.cancel()
        failHelloWaiter(SPLKTransportError.closed)
        let unavailable = SPLKStatusError(.unavailable)
        unaryCalls.values.forEach { $0.complete(.failure(unavailable)) }
        unaryCalls = [:]
        for call in streamCalls.values {
            call.watchdog?.cancel()
            call.continuation.finish(throwing: unavailable)
        }
        streamCalls = [:]
        for call in inboundCalls.values {
            call.watchdog?.cancel()
            call.task?.cancel()
        }
        inboundCalls = [:]
        closeWaiters.forEach { $0.resume() }
        closeWaiters = []
    }

    public var isClosed: Bool {
        phase == .closed
    }

    public func waitUntilClosed() async {
        guard phase != .closed else { return }
        await withCheckedContinuation { closeWaiters.append($0) }
    }

    private static func deadline(of request: SPLKV2Request) -> TimeInterval {
        request.deadlineMs == 0 ? SPLKProtocolInfo.defaultDeadline : TimeInterval(request.deadlineMs) / 1000
    }
}

#endif
