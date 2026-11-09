//
//  FramingTests.swift
//  SPLKProtocolTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import SwiftProtobuf
import Testing
@testable import SPLKProtocol

struct FramingTests {

    private func header(magic: UInt32 = SPLKFraming.magic, format: UInt8 = 1, kind: UInt8 = 0, flags: UInt16 = 0, length: UInt32) -> Data {
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: magic.bigEndian, Array.init))
        data.append(format)
        data.append(kind)
        data.append(contentsOf: withUnsafeBytes(of: flags.bigEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: length.bigEndian, Array.init))
        return data
    }

    @Test func roundTripsMessages() throws {
        let messages = [
            SPLKFrameMessage(kind: .envelope, payload: Data("hello".utf8)),
            SPLKFrameMessage(kind: .envelope, payload: Data()),
            SPLKFrameMessage(kind: .video, payload: Data(repeating: 7, count: 1000)),
        ]
        var stream = Data()
        for message in messages {
            stream.append(try SPLKFraming.encode(message))
        }
        var decoder = SPLKFrameDecoder()
        #expect(try decoder.append(stream) == messages)
    }

    @Test func headerLayout() throws {
        let data = try SPLKFraming.encode(SPLKFrameMessage(kind: .video, payload: Data([1, 2, 3])))
        #expect(data == header(kind: 1, length: 3) + Data([1, 2, 3]))
    }

    @Test func decodesBytesDeliveredOneAtATime() throws {
        let messages = (0..<5).map { SPLKFrameMessage(kind: .envelope, payload: Data(repeating: UInt8($0), count: $0 * 3)) }
        var stream = Data()
        for message in messages {
            stream.append(try SPLKFraming.encode(message, maxFramePayload: 4))
        }
        var decoder = SPLKFrameDecoder()
        var decoded: [SPLKFrameMessage] = []
        for byte in stream {
            decoded += try decoder.append(Data([byte]))
        }
        #expect(decoded == messages)
    }

    @Test func fragmentsMessagesOverOneFrame() throws {
        let payload = Data((0..<(SPLKFraming.maxFramePayload + 1024)).map { UInt8(truncatingIfNeeded: $0) })
        let encoded = try SPLKFraming.encode(SPLKFrameMessage(kind: .envelope, payload: payload))
        #expect(encoded.count == payload.count + 2 * SPLKFraming.headerSize)
        // The first frame carries the continuation flag, the second doesn't.
        #expect(encoded[6...7] == Data([0, 1]))
        let second = SPLKFraming.headerSize + SPLKFraming.maxFramePayload
        #expect(encoded[(second + 6)...(second + 7)] == Data([0, 0]))

        var decoder = SPLKFrameDecoder()
        #expect(try decoder.append(encoded) == [SPLKFrameMessage(kind: .envelope, payload: payload)])
    }

    @Test func rejectsMalformedFrames() {
        func decode(_ data: Data, decoder: SPLKFrameDecoder = SPLKFrameDecoder()) throws {
            var decoder = decoder
            _ = try decoder.append(data)
        }
        #expect(throws: SPLKFrameError.badMagic(0x0000_0001)) {
            // A v1 Peertalk frame starts with its version, 1.
            try decode(header(magic: 1, length: 0))
        }
        #expect(throws: SPLKFrameError.unsupportedFormat(2)) {
            try decode(header(format: 2, length: 0))
        }
        #expect(throws: SPLKFrameError.unknownKind(9)) {
            try decode(header(kind: 9, length: 0))
        }
        #expect(throws: SPLKFrameError.unknownFlags(2)) {
            try decode(header(flags: 2, length: 0))
        }
        #expect(throws: SPLKFrameError.frameTooLarge(11)) {
            try decode(header(length: 11), decoder: SPLKFrameDecoder(maxFramePayload: 10))
        }
        #expect(throws: SPLKFrameError.messageTooLarge(12)) {
            try decode(header(flags: 1, length: 6) + Data(count: 6) + header(length: 6) + Data(count: 6), decoder: SPLKFrameDecoder(maxMessageSize: 10))
        }
        #expect(throws: SPLKFrameError.kindChangedMidMessage) {
            try decode(header(flags: 1, length: 1) + Data([0]) + header(kind: 1, length: 1) + Data([0]))
        }
    }

    @Test func decodesDeepFlatHierarchies() async throws {
        var snapshot = SPLKV2HierarchySnapshot()
        snapshot.nodes = (0..<5000).map { depth in
            var node = SPLKV2Node()
            node.depth = UInt32(depth)
            node.customDisplayTitle = "\(depth)"
            return node
        }
        var envelope = SPLKV2Envelope()
        var response = SPLKV2Response()
        response.hierarchy = snapshot
        envelope.response = response
        let data = try envelope.serializedData()
        #expect(try SPLKV2Envelope(serializedBytes: data) == envelope)
    }
}
