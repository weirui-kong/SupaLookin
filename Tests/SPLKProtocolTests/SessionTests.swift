//
//  SessionTests.swift
//  SPLKProtocolTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Testing
@testable import SPLKProtocol

struct HandshakeTests {

    @Test func negotiatesCapabilitiesAndSummary() async throws {
        let harness = try await Harness.memory(hostCapabilities: [SPLKCapability.object, SPLKCapability.details], clientCapabilities: [SPLKCapability.object, SPLKCapability.image])
        #expect(harness.session.capabilities == [SPLKCapability.object])
        #expect(harness.session.serverHello.serverVersion == "9.9.9")
        #expect(harness.session.serverHello.app.name == "Demo")
        #expect(await harness.host.currentSessionID == harness.session.serverHello.sessionID)
        await harness.session.close()
    }

    @Test func hostRejectsAnotherGeneration() async throws {
        let host = Harness.makeHost()
        let (connection, hello) = try await Harness.rawConnection(to: host, hello: Harness.clientHello(role: .control, generation: 3))
        #expect(hello.status.code == .failedPrecondition)
        #expect(hello.status.reason == "generation_mismatch")
        await connection.waitUntilClosed()
        #expect(await host.currentSessionID == nil)
    }

    @Test func clientRejectsAnotherGeneration() async throws {
        await #expect(throws: SPLKHandshakeError.generationMismatch(3)) {
            _ = try await SPLKClientSession.connect(configuration: Harness.clientConfiguration()) { _ in
                let (client, server) = SPLKMemoryByteStream.pair()
                _ = Task {
                    let connection = SPLKRPCConnection(stream: server)
                    await connection.start()
                    _ = try await connection.receiveHello(timeout: 2)
                    var hello = SPLKV2ServerHello()
                    hello.protocolGeneration = 3
                    try await connection.sendHello(hello)
                }
                return client
            }
        }
    }

    @Test func bulkNeedsAKnownSession() async throws {
        let host = Harness.makeHost()
        let (connection, hello) = try await Harness.rawConnection(to: host, hello: Harness.clientHello(role: .bulk, sessionID: Data([1, 2, 3])))
        #expect(hello.status.code == .notFound)
        await connection.waitUntilClosed()
    }

    @Test func videoChannelIsUnsupported() async throws {
        let host = Harness.makeHost()
        let (_, hello) = try await Harness.rawConnection(to: host, hello: Harness.clientHello(role: .video))
        #expect(hello.status.code == .unimplemented)
    }

    @Test func silentPeerTimesOut() async throws {
        let started = Date()
        await #expect(throws: SPLKHandshakeError.noServerHello) {
            _ = try await SPLKClientSession.connect(configuration: Harness.clientConfiguration(handshakeTimeout: 0.2)) { _ in
                SPLKMemoryByteStream.pair().0
            }
        }
        #expect(Date().timeIntervalSince(started) < 1.5)
    }

    @Test func closingPeerFailsHandshake() async throws {
        await #expect(throws: SPLKHandshakeError.noServerHello) {
            _ = try await SPLKClientSession.connect(configuration: Harness.clientConfiguration()) { _ in
                let (client, server) = SPLKMemoryByteStream.pair()
                server.close()
                return client
            }
        }
    }

    @Test func newControlConnectionReplacesSession() async throws {
        let host = Harness.makeHost()
        let first = try await Harness.connect(to: host)
        let second = try await Harness.connect(to: host)
        await first.waitUntilClosed()
        #expect(await host.currentSessionID == second.serverHello.sessionID)
        #expect(try await second.unary(Fixtures.getObject(5)).objectOID == 5)
        await second.close()
    }
}

struct CallTests {

    @Test func unaryStreamAndOneway() async throws {
        let calls = SPLKLocked<[String]>([])
        let handler = ClosureHandler { request, context in
            calls.withLock { $0.append("\(context.channel)") }
            return try await Fixtures.echoHandler.handle(request, context: context)
        }
        let harness = try await Harness.memory(handler: handler)
        #expect(try await harness.session.unary(Fixtures.getObject(42)).objectOID == 42)
        #expect(try await collectOIDs(harness.session.stream(Fixtures.fetchDetails(count: 4))) == [0, 1, 2, 3])
        try await harness.session.oneway(Fixtures.invoke("ok"))
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(calls.withLock { $0 } == ["control", "bulk", "control"])
        await harness.session.close()
    }

    @Test func onewayFailureReachesTheErrorStream() async throws {
        let harness = try await Harness.memory()
        try await harness.session.oneway(Fixtures.invoke("not-found"))
        var iterator = harness.session.onewayFailures.makeAsyncIterator()
        let failure = await iterator.next()
        #expect(failure?.error.code == .notFound)
        await harness.session.close()
    }

    @Test func statusErrorsCrossTheWire() async throws {
        let harness = try await Harness.memory()
        let error = await statusError { _ = try await harness.session.unary(Fixtures.invoke("not-found")) }
        #expect(error == SPLKStatusError(.notFound, reason: "object_deallocated", title: "Gone"))
        await harness.session.close()
    }

    @Test func otherErrorsBecomeInternal() async throws {
        let harness = try await Harness.memory()
        let error = await statusError { _ = try await harness.session.unary(Fixtures.invoke("other")) }
        #expect(error?.code == .internal)
        await harness.session.close()
    }

    @Test func requestWithoutCallIsUnimplemented() async throws {
        let host = Harness.makeHost()
        let (connection, hello) = try await Harness.rawConnection(to: host, hello: Harness.clientHello(role: .control))
        await connection.startDispatching(handler: nil, sessionID: hello.sessionID, channel: .control)
        let error = await statusError { _ = try await connection.unary(SPLKV2Request(), id: 1) }
        #expect(error?.code == .unimplemented)
        await connection.close()
    }

    @Test func missingCapabilityIsRefusedLocally() async throws {
        let called = Flag()
        let handler = ClosureHandler { _, _ in
            called.set()
            return .response(nil)
        }
        let harness = try await Harness.memory(handler: handler, clientCapabilities: [SPLKCapability.details])
        let error = await statusError { _ = try await harness.session.unary(Fixtures.getObject(1)) }
        #expect(error == SPLKStatusError(.unimplemented, reason: "capability_missing"))
        #expect(!called.isSet)
        await harness.session.close()
    }

    @Test func sameMethodCallsAreNotDiscarded() async throws {
        let handler = ClosureHandler { request, context in
            try await Task.sleep(nanoseconds: 100_000_000)
            return try await Fixtures.echoHandler.handle(request, context: context)
        }
        let harness = try await Harness.memory(handler: handler)
        async let first = harness.session.unary(Fixtures.getObject(1))
        async let second = harness.session.unary(Fixtures.getObject(2))
        #expect(try await [first.objectOID, second.objectOID] == [1, 2])
        await harness.session.close()
    }

    @Test func slowBulkStreamDoesNotDelayControl() async throws {
        let handler = ClosureHandler { request, context in
            guard case .fetchDetails = request.call else {
                return try await Fixtures.echoHandler.handle(request, context: context)
            }
            return .stream(AsyncThrowingStream { continuation in
                Task {
                    for oid in 0..<5 {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        continuation.yield(Fixtures.detail(UInt64(oid)))
                    }
                    continuation.finish()
                }
            })
        }
        let harness = try await Harness.memory(handler: handler)
        let details = Task { try await collectOIDs(harness.session.stream(Fixtures.fetchDetails(count: 5))) }
        try await Task.sleep(nanoseconds: 50_000_000)
        let started = Date()
        #expect(try await harness.session.unary(Fixtures.getObject(7)).objectOID == 7)
        #expect(Date().timeIntervalSince(started) < 0.15)
        #expect(try await details.value == [0, 1, 2, 3, 4])
        await harness.session.close()
    }
}

struct DeadlineAndCancellationTests {

    @Test func hostEnforcesTheDeadline() async throws {
        let cancelled = Flag()
        let handler = ClosureHandler { _, _ in
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                cancelled.set()
                throw error
            }
            return .response(nil)
        }
        let harness = try await Harness.memory(handler: handler)
        let started = Date()
        let error = await statusError { _ = try await harness.session.unary(Fixtures.getObject(1), deadlineMs: 200) }
        #expect(error?.code == .deadlineExceeded)
        #expect(Date().timeIntervalSince(started) < 1)
        #expect(await cancelled.wait())
        await harness.session.close()
    }

    @Test func clientEnforcesTheDeadlineWhenTheHostHangs() async throws {
        let handler = ClosureHandler { _, _ in
            // Ignores cancellation, so the host never answers.
            await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
            return .response(nil)
        }
        let harness = try await Harness.memory(handler: handler)
        let started = Date()
        let error = await statusError { _ = try await harness.session.unary(Fixtures.getObject(1), deadlineMs: 100) }
        #expect(error?.code == .deadlineExceeded)
        let elapsed = Date().timeIntervalSince(started)
        #expect(elapsed > 1 && elapsed < 2)
        await harness.session.close()
    }

    @Test func streamDeadlineRestartsPerItem() async throws {
        let handler = ClosureHandler { _, _ in
            .stream(AsyncThrowingStream { continuation in
                Task {
                    for oid in 0..<5 {
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        continuation.yield(Fixtures.detail(UInt64(oid)))
                    }
                    continuation.finish()
                }
            })
        }
        let harness = try await Harness.memory(handler: handler)
        #expect(try await collectOIDs(harness.session.stream(Fixtures.fetchDetails(count: 5), deadlineMs: 300)) == [0, 1, 2, 3, 4])
        await harness.session.close()
    }

    @Test func cancellingAUnaryCallReachesTheHandler() async throws {
        let started = Flag()
        let cancelled = Flag()
        let handler = ClosureHandler { _, _ in
            started.set()
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                cancelled.set()
                throw error
            }
            return .response(nil)
        }
        let harness = try await Harness.memory(handler: handler)
        let call = Task { try await harness.session.unary(Fixtures.getObject(1)) }
        #expect(await started.wait())
        call.cancel()
        let error = await statusError { _ = try await call.value }
        #expect(error?.code == .cancelled)
        #expect(await cancelled.wait())
        await harness.session.close()
    }

    private static func endlessStreamHandler(cancelled: Flag) -> ClosureHandler {
        ClosureHandler { _, _ in
            .stream(AsyncThrowingStream { continuation in
                let producer = Task {
                    for oid in 0..<1000 {
                        continuation.yield(Fixtures.detail(UInt64(oid)))
                        try? await Task.sleep(nanoseconds: 20_000_000)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    producer.cancel()
                    cancelled.set()
                }
            })
        }
    }

    @Test func cancellingAStreamConsumerReachesTheHandler() async throws {
        let cancelled = Flag()
        let harness = try await Harness.memory(handler: Self.endlessStreamHandler(cancelled: cancelled))
        let firstItem = Flag()
        let consumer = Task {
            for try await _ in try await harness.session.stream(Fixtures.fetchDetails(count: 1000)) {
                firstItem.set()
            }
        }
        #expect(await firstItem.wait())
        consumer.cancel()
        #expect(await cancelled.wait())
        await harness.session.close()
    }

    @Test func releasingAStreamReachesTheHandler() async throws {
        let cancelled = Flag()
        let harness = try await Harness.memory(handler: Self.endlessStreamHandler(cancelled: cancelled))
        try await Task {
            for try await _ in try await harness.session.stream(Fixtures.fetchDetails(count: 1000)) {
                break
            }
        }.value
        #expect(await cancelled.wait())
        await harness.session.close()
    }
}

struct LivenessTests {

    @Test func heartbeatsKeepTheSessionAlive() async throws {
        let harness = try await Harness.memory(liveness: 0.5, heartbeat: 0.1)
        try await Task.sleep(nanoseconds: 1_200_000_000)
        #expect(try await harness.session.unary(Fixtures.getObject(3)).objectOID == 3)
        await harness.session.close()
    }

    @Test func silenceClosesTheSession() async throws {
        let harness = try await Harness.memory(liveness: 0.3, heartbeat: 60)
        let started = Date()
        await harness.session.waitUntilClosed()
        #expect(Date().timeIntervalSince(started) < 1.5)
        #expect(await harness.host.currentSessionID == nil)
    }
}
