//
//  TransportTests.swift
//  SPLKProtocolTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Testing
@testable import SPLKProtocol

struct TransportTests {

    private func exercise(_ session: SPLKClientSession) async throws {
        #expect(try await session.unary(Fixtures.getObject(11)).objectOID == 11)
        #expect(try await collectOIDs(session.stream(Fixtures.fetchDetails(count: 3))) == [0, 1, 2])
        let error = await statusError { _ = try await session.unary(Fixtures.invoke("not-found")) }
        #expect(error?.code == .notFound)
    }

    @Test func networkLoopback() async throws {
        let listener = try await SPLKListener.bind(ports: nil)
        #expect(listener.port != 0)
        let host = Harness.makeHost()
        await host.serve(listener)
        let session = try await SPLKClientSession.connect(configuration: Harness.clientConfiguration()) { _ in
            try await SPLKNetworkByteStream.connect(host: "127.0.0.1", port: listener.port, timeout: 2)
        }
        try await exercise(session)
        await session.close()
        await host.close()
        listener.close()
    }

    @Test func listenerSkipsBusyPorts() async throws {
        let first = try await SPLKListener.bind(ports: nil)
        let second = try await SPLKListener.bind(ports: first.port...(first.port &+ 20))
        #expect(second.port != first.port)
        first.close()
        second.close()
    }

    @Test func refusedConnectionFails() async throws {
        let listener = try await SPLKListener.bind(ports: nil)
        let port = listener.port
        listener.close()
        try await Task.sleep(nanoseconds: 100_000_000)
        await #expect(throws: (any Error).self) {
            _ = try await SPLKNetworkByteStream.connect(host: "127.0.0.1", port: port, timeout: 1)
        }
    }

    @Test func dispatchIOSocketPair() async throws {
        let host = Harness.makeHost()
        let session = try await SPLKClientSession.connect(configuration: Harness.clientConfiguration()) { _ in
            var fds: [Int32] = [0, 0]
            guard socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0 else {
                throw POSIXError(.EIO)
            }
            await host.accept(SPLKDispatchIOByteStream(fileDescriptor: fds[0]))
            return SPLKDispatchIOByteStream(fileDescriptor: fds[1])
        }
        try await exercise(session)
        await session.close()
        await host.close()
    }

    @Test func largeMessagesCrossTheWire() async throws {
        let payload = Data((0..<(SPLKFraming.maxFramePayload + 4096)).map { UInt8(truncatingIfNeeded: $0 &* 31) })
        let handler = ClosureHandler { _, _ in
            var image = SPLKV2EncodedImage()
            image.format = .png
            image.data = payload
            return .response(.image(image))
        }
        let listener = try await SPLKListener.bind(ports: nil)
        let host = Harness.makeHost(handler: handler)
        await host.serve(listener)
        let session = try await SPLKClientSession.connect(configuration: Harness.clientConfiguration()) { _ in
            try await SPLKNetworkByteStream.connect(host: "127.0.0.1", port: listener.port, timeout: 2)
        }
        var call = SPLKV2GetImageViewImage()
        call.oid = 1
        let response = try await session.unary(.getImageViewImage(call), deadlineMs: 10_000)
        guard case .image(let image) = response.result else {
            Issue.record("no image")
            return
        }
        #expect(image.data == payload)
        await session.close()
        await host.close()
        listener.close()
    }
}
