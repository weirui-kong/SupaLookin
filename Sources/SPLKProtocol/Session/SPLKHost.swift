//
//  SPLKHost.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SHARED

import Foundation
import SwiftProtobuf

public actor SPLKHost {

    public struct Configuration: Sendable {
        public var serverVersion: String
        public var capabilities: Set<String>
        public var handshakeTimeout: TimeInterval
        public var livenessTimeout: TimeInterval

        public init(
            serverVersion: String,
            capabilities: Set<String>,
            handshakeTimeout: TimeInterval = SPLKProtocolInfo.handshakeTimeout,
            livenessTimeout: TimeInterval = SPLKProtocolInfo.livenessTimeout
        ) {
            self.serverVersion = serverVersion
            self.capabilities = capabilities
            self.handshakeTimeout = handshakeTimeout
            self.livenessTimeout = livenessTimeout
        }
    }

    public typealias AppSummaryProvider = @Sendable () async -> SPLKV2AppSummary

    private final class Session {
        let id: Data
        let control: SPLKRPCConnection
        var bulk: [SPLKRPCConnection] = []
        var liveness: SPLKWatchdog?

        init(id: Data, control: SPLKRPCConnection) {
            self.id = id
            self.control = control
        }
    }

    private let configuration: Configuration
    private let handler: any SPLKRequestHandler
    private let appSummary: AppSummaryProvider
    private var session: Session?
    private var serveTasks: [Task<Void, Never>] = []

    public init(configuration: Configuration, handler: any SPLKRequestHandler, appSummary: @escaping AppSummaryProvider) {
        self.configuration = configuration
        self.handler = handler
        self.appSummary = appSummary
    }

    public var currentSessionID: Data? {
        session?.id
    }

    public func serve(_ listener: SPLKListener) {
        serveTasks.append(Task {
            for await stream in listener.connections {
                self.accept(stream)
            }
        })
    }

    public func accept(_ stream: any SPLKByteStream) {
        let connection = SPLKRPCConnection(stream: stream)
        Task {
            await connection.start()
            await self.handshake(connection)
        }
    }

    private func handshake(_ connection: SPLKRPCConnection) async {
        guard let payload = try? await connection.receiveHello(timeout: configuration.handshakeTimeout),
              let clientHello = try? SPLKV2ClientHello(serializedBytes: payload) else {
            await connection.close()
            return
        }
        guard clientHello.protocolGeneration == SPLKProtocolInfo.generation else {
            await reject(connection, SPLKStatusError(.failedPrecondition, reason: "generation_mismatch"))
            return
        }
        switch clientHello.role {
        case .control:
            await openSession(on: connection, clientVersion: clientHello.clientVersion)
        case .bulk:
            guard let session, session.id == clientHello.sessionID else {
                await reject(connection, SPLKStatusError(.notFound, reason: "unknown_session"))
                return
            }
            try? await connection.sendHello(await serverHello(sessionID: session.id))
            session.bulk.append(connection)
            await connection.startDispatching(handler: handler, sessionID: session.id, channel: .bulk, clientVersion: clientHello.clientVersion)
        case .video, .unspecified, .UNRECOGNIZED:
            await reject(connection, SPLKStatusError(.unimplemented, reason: "channel_unsupported"))
        }
    }

    private func openSession(on connection: SPLKRPCConnection, clientVersion: String) async {
        await closeSession()
        let id = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let newSession = Session(id: id, control: connection)
        session = newSession

        do {
            try await connection.sendHello(await serverHello(sessionID: id))
        } catch {
            await closeSession(id)
            return
        }
        let liveness = SPLKWatchdog(timeout: configuration.livenessTimeout) { [weak self] in
            Task { await self?.closeSession(id) }
        }
        newSession.liveness = liveness
        await connection.startDispatching(handler: handler, sessionID: id, channel: .control, clientVersion: clientVersion, activity: { liveness.touch() })
        Task {
            await connection.waitUntilClosed()
            await self.closeSession(id)
        }
    }

    private func serverHello(sessionID: Data) async -> SPLKV2ServerHello {
        var hello = SPLKV2ServerHello()
        hello.protocolGeneration = SPLKProtocolInfo.generation
        hello.serverVersion = configuration.serverVersion
        hello.sessionID = sessionID
        hello.capabilities = configuration.capabilities.sorted()
        hello.app = await appSummary()
        return hello
    }

    private func reject(_ connection: SPLKRPCConnection, _ error: SPLKStatusError) async {
        var hello = SPLKV2ServerHello()
        hello.status = error.status
        hello.protocolGeneration = SPLKProtocolInfo.generation
        hello.serverVersion = configuration.serverVersion
        try? await connection.sendHello(hello)
        await connection.close()
    }

    // Closes the current session, or only the session with `id` if one is given.
    private func closeSession(_ id: Data? = nil) async {
        guard let current = session, id == nil || current.id == id else { return }
        session = nil
        current.liveness?.cancel()
        await current.control.close()
        for connection in current.bulk {
            await connection.close()
        }
        await handler.sessionDidEnd(current.id)
    }

    public func close() async {
        serveTasks.forEach { $0.cancel() }
        serveTasks = []
        await closeSession()
    }
}

#endif
