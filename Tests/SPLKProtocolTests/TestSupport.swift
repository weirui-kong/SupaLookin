//
//  TestSupport.swift
//  SPLKProtocolTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
@testable import SPLKProtocol

struct ClosureHandler: SPLKRequestHandler {
    let body: @Sendable (SPLKV2Request, SPLKRequestContext) async throws -> SPLKHandlerResult

    func handle(_ request: SPLKV2Request, context: SPLKRequestContext) async throws -> SPLKHandlerResult {
        try await body(request, context)
    }
}

final class Flag: Sendable {
    private let value = SPLKLocked(false)

    func set() {
        value.withLock { $0 = true }
    }

    var isSet: Bool {
        value.withLock { $0 }
    }

    // Polls, since the flagged event happens on another task.
    func wait(timeout: TimeInterval = 2) async -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if isSet { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return isSet
    }
}

enum Fixtures {
    static let allCapabilities: Set<String> = [
        SPLKCapability.app, SPLKCapability.hierarchy, SPLKCapability.details, SPLKCapability.attrModify,
        SPLKCapability.attrCustom, SPLKCapability.attrGroups, SPLKCapability.object, SPLKCapability.objectInvoke,
        SPLKCapability.objectSelectors, SPLKCapability.image, SPLKCapability.gestureToggle,
    ]

    static func appSummary() -> SPLKV2AppSummary {
        var summary = SPLKV2AppSummary()
        summary.name = "Demo"
        summary.bundleIdentifier = "icu.retrouvailles.demo"
        return summary
    }

    static func getObject(_ oid: UInt64) -> SPLKV2Request.OneOf_Call {
        var call = SPLKV2GetObject()
        call.oid = oid
        return .getObject(call)
    }

    static func fetchDetails(count: Int) -> SPLKV2Request.OneOf_Call {
        var package = SPLKV2DetailTaskPackage()
        package.tasks = (0..<count).map { index in
            var task = SPLKV2DetailTask()
            task.oid = UInt64(index)
            return task
        }
        var call = SPLKV2FetchDetails()
        call.packages = [package]
        return .fetchDetails(call)
    }

    static func invoke(_ text: String) -> SPLKV2Request.OneOf_Call {
        var call = SPLKV2InvokeMethod()
        call.text = text
        return .invokeMethod(call)
    }

    static func detail(_ oid: UInt64) -> SPLKV2StreamItem {
        var detail = SPLKV2NodeDetail()
        detail.oid = oid
        var item = SPLKV2StreamItem()
        item.item = .nodeDetail(detail)
        return item
    }

    // getObject echoes its oid, fetchDetails streams one detail per task, invokeMethod fails as its text says.
    static let echoHandler = ClosureHandler { request, _ in
        switch request.call {
        case .getObject(let call):
            var object = SPLKV2ObjectRef()
            object.oid = call.oid
            return .response(.object(object))
        case .fetchDetails(let call):
            let oids = call.packages.flatMap(\.tasks).map(\.oid)
            return .stream(AsyncThrowingStream { continuation in
                oids.forEach { continuation.yield(detail($0)) }
                continuation.finish()
            })
        case .invokeMethod(let call) where call.text == "not-found":
            throw SPLKStatusError(.notFound, reason: "object_deallocated", title: "Gone")
        case .invokeMethod(let call) where call.text == "other":
            throw NSError(domain: "Test", code: 1)
        default:
            return .response(.empty(SPLKV2Empty()))
        }
    }
}

struct Harness {
    let host: SPLKHost
    let session: SPLKClientSession

    static func memory(
        handler: any SPLKRequestHandler = Fixtures.echoHandler,
        hostCapabilities: Set<String> = Fixtures.allCapabilities,
        clientCapabilities: Set<String> = Fixtures.allCapabilities,
        liveness: TimeInterval = SPLKProtocolInfo.livenessTimeout,
        heartbeat: TimeInterval = SPLKProtocolInfo.heartbeatInterval
    ) async throws -> Harness {
        let host = makeHost(handler: handler, capabilities: hostCapabilities, liveness: liveness)
        let session = try await connect(to: host, capabilities: clientCapabilities, heartbeat: heartbeat)
        return Harness(host: host, session: session)
    }

    static func makeHost(handler: any SPLKRequestHandler = Fixtures.echoHandler, capabilities: Set<String> = Fixtures.allCapabilities, liveness: TimeInterval = SPLKProtocolInfo.livenessTimeout) -> SPLKHost {
        SPLKHost(
            configuration: SPLKHost.Configuration(serverVersion: "9.9.9", capabilities: capabilities, livenessTimeout: liveness),
            handler: handler,
            appSummary: { Fixtures.appSummary() }
        )
    }

    static func connect(to host: SPLKHost, capabilities: Set<String> = Fixtures.allCapabilities, heartbeat: TimeInterval = SPLKProtocolInfo.heartbeatInterval) async throws -> SPLKClientSession {
        try await SPLKClientSession.connect(configuration: clientConfiguration(capabilities: capabilities, heartbeat: heartbeat)) { _ in
            let (client, server) = SPLKMemoryByteStream.pair()
            await host.accept(server)
            return client
        }
    }

    static func clientConfiguration(capabilities: Set<String> = Fixtures.allCapabilities, heartbeat: TimeInterval = SPLKProtocolInfo.heartbeatInterval, handshakeTimeout: TimeInterval = SPLKProtocolInfo.handshakeTimeout) -> SPLKClientSession.Configuration {
        SPLKClientSession.Configuration(clientName: "Tests", clientVersion: "1.0", capabilities: capabilities, handshakeTimeout: handshakeTimeout, heartbeatInterval: heartbeat)
    }

    // A control connection driven by hand, for what SPLKClientSession never sends.
    static func rawConnection(to host: SPLKHost, hello: SPLKV2ClientHello) async throws -> (SPLKRPCConnection, SPLKV2ServerHello) {
        let (client, server) = SPLKMemoryByteStream.pair()
        await host.accept(server)
        let connection = SPLKRPCConnection(stream: client)
        await connection.start()
        try await connection.sendHello(hello)
        let payload = try await connection.receiveHello(timeout: 2)
        return (connection, try SPLKV2ServerHello(serializedBytes: payload))
    }

    static func clientHello(role: SPLKV2ChannelRole, generation: UInt32 = SPLKProtocolInfo.generation, sessionID: Data = Data()) -> SPLKV2ClientHello {
        var hello = SPLKV2ClientHello()
        hello.protocolGeneration = generation
        hello.role = role
        hello.sessionID = sessionID
        return hello
    }
}

extension SPLKV2Response {
    var objectOID: UInt64? {
        if case .object(let object) = result {
            return object.oid
        }
        return nil
    }
}

func collectOIDs(_ items: AsyncThrowingStream<SPLKV2StreamItem, Error>) async throws -> [UInt64] {
    var oids: [UInt64] = []
    for try await item in items {
        if case .nodeDetail(let detail) = item.item {
            oids.append(detail.oid)
        }
    }
    return oids
}

func statusError(_ body: () async throws -> Void) async -> SPLKStatusError? {
    do {
        try await body()
        return nil
    } catch {
        return error as? SPLKStatusError
    }
}
