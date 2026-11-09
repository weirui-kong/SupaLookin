//
//  SPLKClientSession.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import SwiftProtobuf

public enum SPLKHandshakeError: Error, Equatable {
    // The peer closed the connection or stayed silent; a v1 server does this.
    case noServerHello
    case rejected(SPLKStatusError)
    case generationMismatch(UInt32)
}

public actor SPLKClientSession {

    public struct Configuration: Sendable {
        public var clientName: String
        public var clientVersion: String
        public var capabilities: Set<String>
        public var handshakeTimeout: TimeInterval
        public var heartbeatInterval: TimeInterval

        public init(
            clientName: String,
            clientVersion: String,
            capabilities: Set<String>,
            handshakeTimeout: TimeInterval = SPLKProtocolInfo.handshakeTimeout,
            heartbeatInterval: TimeInterval = SPLKProtocolInfo.heartbeatInterval
        ) {
            self.clientName = clientName
            self.clientVersion = clientVersion
            self.capabilities = capabilities
            self.handshakeTimeout = handshakeTimeout
            self.heartbeatInterval = heartbeatInterval
        }
    }

    public typealias StreamOpener = @Sendable (SPLKV2ChannelRole) async throws -> any SPLKByteStream

    public nonisolated let serverHello: SPLKV2ServerHello
    public nonisolated let capabilities: Set<String>
    public nonisolated let onewayFailures: AsyncStream<SPLKOnewayFailure>

    private let control: SPLKRPCConnection
    private let bulk: SPLKRPCConnection
    private let ids = SPLKRequestIDAllocator()
    private let onewayFailureContinuation: AsyncStream<SPLKOnewayFailure>.Continuation
    private let heartbeatInterval: TimeInterval
    private var heartbeatTask: Task<Void, Never>?
    private var monitorTasks: [Task<Void, Never>] = []

    private init(serverHello: SPLKV2ServerHello, capabilities: Set<String>, control: SPLKRPCConnection, bulk: SPLKRPCConnection, heartbeatInterval: TimeInterval) {
        self.serverHello = serverHello
        self.capabilities = capabilities
        self.control = control
        self.bulk = bulk
        self.heartbeatInterval = heartbeatInterval
        (onewayFailures, onewayFailureContinuation) = AsyncStream<SPLKOnewayFailure>.makeStream()
    }

    public static func connect(configuration: Configuration, open: StreamOpener) async throws -> SPLKClientSession {
        let control = SPLKRPCConnection(stream: try await open(.control))
        await control.start()
        var bulk: SPLKRPCConnection?
        do {
            let hello = try await handshake(control, role: .control, sessionID: Data(), configuration: configuration)
            let bulkConnection = SPLKRPCConnection(stream: try await open(.bulk))
            bulk = bulkConnection
            await bulkConnection.start()
            _ = try await handshake(bulkConnection, role: .bulk, sessionID: hello.sessionID, configuration: configuration)

            let capabilities = configuration.capabilities.intersection(hello.capabilities)
            let session = SPLKClientSession(serverHello: hello, capabilities: capabilities, control: control, bulk: bulkConnection, heartbeatInterval: configuration.heartbeatInterval)
            await session.begin()
            return session
        } catch {
            await control.close()
            await bulk?.close()
            throw error
        }
    }

    private static func handshake(_ connection: SPLKRPCConnection, role: SPLKV2ChannelRole, sessionID: Data, configuration: Configuration) async throws -> SPLKV2ServerHello {
        var clientHello = SPLKV2ClientHello()
        clientHello.protocolGeneration = SPLKProtocolInfo.generation
        clientHello.clientName = configuration.clientName
        clientHello.clientVersion = configuration.clientVersion
        clientHello.capabilities = configuration.capabilities.sorted()
        clientHello.role = role
        clientHello.sessionID = sessionID

        let payload: Data
        do {
            try await connection.sendHello(clientHello)
            payload = try await connection.receiveHello(timeout: configuration.handshakeTimeout)
        } catch {
            throw SPLKHandshakeError.noServerHello
        }
        guard let hello = try? SPLKV2ServerHello(serializedBytes: payload) else {
            throw SPLKHandshakeError.noServerHello
        }
        if let error = SPLKStatusError(status: hello.status) {
            throw SPLKHandshakeError.rejected(error)
        }
        guard hello.protocolGeneration == SPLKProtocolInfo.generation else {
            throw SPLKHandshakeError.generationMismatch(hello.protocolGeneration)
        }
        return hello
    }

    private func begin() async {
        let continuation = onewayFailureContinuation
        let onewayFailure: @Sendable (SPLKOnewayFailure) -> Void = { continuation.yield($0) }
        await control.startDispatching(handler: nil, sessionID: serverHello.sessionID, channel: .control, onewayFailure: onewayFailure)
        await bulk.startDispatching(handler: nil, sessionID: serverHello.sessionID, channel: .bulk, onewayFailure: onewayFailure)

        let interval = UInt64(heartbeatInterval * 1_000_000_000)
        heartbeatTask = Task { [control] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled, (try? await control.sendHeartbeat()) != nil else { return }
            }
        }
        // Losing either connection ends the session; the caller reconnects as a whole.
        for connection in [control, bulk] {
            monitorTasks.append(Task {
                await connection.waitUntilClosed()
                await self.close()
            })
        }
    }

    // MARK: - Calls

    public func unary(_ call: SPLKV2Request.OneOf_Call, deadlineMs: UInt32 = 0, leaseID: Data = Data()) async throws -> SPLKV2Response {
        let (request, connection) = try prepare(call, deadlineMs: deadlineMs, leaseID: leaseID)
        return try await connection.unary(request, id: ids.allocate())
    }

    public func stream(_ call: SPLKV2Request.OneOf_Call, deadlineMs: UInt32 = 0, leaseID: Data = Data()) async throws -> AsyncThrowingStream<SPLKV2StreamItem, Error> {
        let (request, connection) = try prepare(call, deadlineMs: deadlineMs, leaseID: leaseID)
        return try await connection.stream(request, id: ids.allocate())
    }

    public func oneway(_ call: SPLKV2Request.OneOf_Call, leaseID: Data = Data()) async throws {
        let (request, connection) = try prepare(call, deadlineMs: 0, leaseID: leaseID)
        try await connection.oneway(request, id: ids.allocate())
    }

    private func prepare(_ call: SPLKV2Request.OneOf_Call, deadlineMs: UInt32, leaseID: Data) throws -> (SPLKV2Request, SPLKRPCConnection) {
        guard call.requiredCapabilities.isSubset(of: capabilities) else {
            throw SPLKStatusError(.unimplemented, reason: "capability_missing")
        }
        var request = SPLKV2Request()
        request.call = call
        request.deadlineMs = deadlineMs
        request.leaseID = leaseID
        return (request, call.channel == .bulk ? bulk : control)
    }

    // MARK: - Lifecycle

    public func close() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        onewayFailureContinuation.finish()
        await control.close()
        await bulk.close()
    }

    public func waitUntilClosed() async {
        await control.waitUntilClosed()
        await bulk.waitUntilClosed()
    }
}
