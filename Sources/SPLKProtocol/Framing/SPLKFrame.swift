//
//  SPLKFrame.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SHARED

import Foundation

public enum SPLKFrameKind: UInt8, Sendable {
    case envelope = 0
    case video = 1
}

public struct SPLKFrameMessage: Sendable, Equatable {
    public var kind: SPLKFrameKind
    public var payload: Data

    public init(kind: SPLKFrameKind, payload: Data) {
        self.kind = kind
        self.payload = payload
    }
}

public enum SPLKFrameError: Error, Equatable {
    case badMagic(UInt32)
    case unsupportedFormat(UInt8)
    case unknownKind(UInt8)
    case unknownFlags(UInt16)
    case frameTooLarge(Int)
    case messageTooLarge(Int)
    case kindChangedMidMessage
}

public enum SPLKFraming {
    public static let magic: UInt32 = 0x5350_4C4B
    public static let format: UInt8 = 1
    public static let headerSize = 12
    public static let maxFramePayload = 16 * 1024 * 1024
    public static let maxMessageSize = 256 * 1024 * 1024

    static let continuesFlag: UInt16 = 1 << 0

    // All frames of a message come back as one buffer: writing it in one call keeps fragments contiguous.
    public static func encode(_ message: SPLKFrameMessage, maxFramePayload: Int = maxFramePayload) throws -> Data {
        let payload = message.payload
        guard payload.count <= maxMessageSize else {
            throw SPLKFrameError.messageTooLarge(payload.count)
        }
        let fragmentCount = max(1, (payload.count + maxFramePayload - 1) / maxFramePayload)
        var data = Data(capacity: payload.count + fragmentCount * headerSize)
        var offset = payload.startIndex
        for index in 0..<fragmentCount {
            let end = min(offset + maxFramePayload, payload.endIndex)
            let isLast = index == fragmentCount - 1
            appendHeader(to: &data, kind: message.kind, flags: isLast ? 0 : continuesFlag, length: UInt32(end - offset))
            data.append(payload[offset..<end])
            offset = end
        }
        return data
    }

    private static func appendHeader(to data: inout Data, kind: SPLKFrameKind, flags: UInt16, length: UInt32) {
        data.append(contentsOf: withUnsafeBytes(of: magic.bigEndian, Array.init))
        data.append(format)
        data.append(kind.rawValue)
        data.append(contentsOf: withUnsafeBytes(of: flags.bigEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: length.bigEndian, Array.init))
    }
}

public struct SPLKFrameDecoder: Sendable {
    private var buffer = Data()
    private var partialKind: SPLKFrameKind?
    private var partialPayload = Data()
    private let maxFramePayload: Int
    private let maxMessageSize: Int

    public init(maxFramePayload: Int = SPLKFraming.maxFramePayload, maxMessageSize: Int = SPLKFraming.maxMessageSize) {
        self.maxFramePayload = maxFramePayload
        self.maxMessageSize = maxMessageSize
    }

    public mutating func append(_ bytes: Data) throws -> [SPLKFrameMessage] {
        buffer.append(bytes)
        var messages: [SPLKFrameMessage] = []
        var cursor = buffer.startIndex
        while buffer.endIndex - cursor >= SPLKFraming.headerSize {
            let header = try parseHeader(at: cursor)
            let frameEnd = cursor + SPLKFraming.headerSize + header.length
            guard frameEnd <= buffer.endIndex else {
                break
            }
            let fragment = buffer[(cursor + SPLKFraming.headerSize)..<frameEnd]
            cursor = frameEnd

            if let partialKind, partialKind != header.kind {
                throw SPLKFrameError.kindChangedMidMessage
            }
            guard partialPayload.count + fragment.count <= maxMessageSize else {
                throw SPLKFrameError.messageTooLarge(partialPayload.count + fragment.count)
            }
            if header.continues {
                partialKind = header.kind
                partialPayload.append(fragment)
            } else if partialKind == nil {
                messages.append(SPLKFrameMessage(kind: header.kind, payload: Data(fragment)))
            } else {
                partialPayload.append(fragment)
                messages.append(SPLKFrameMessage(kind: header.kind, payload: partialPayload))
                partialKind = nil
                partialPayload = Data()
            }
        }
        buffer = cursor == buffer.endIndex ? Data() : Data(buffer[cursor...])
        return messages
    }

    private func parseHeader(at start: Data.Index) throws -> (kind: SPLKFrameKind, continues: Bool, length: Int) {
        let magic = readUInt32(at: start)
        guard magic == SPLKFraming.magic else {
            throw SPLKFrameError.badMagic(magic)
        }
        let format = buffer[start + 4]
        guard format == SPLKFraming.format else {
            throw SPLKFrameError.unsupportedFormat(format)
        }
        let rawKind = buffer[start + 5]
        guard let kind = SPLKFrameKind(rawValue: rawKind) else {
            throw SPLKFrameError.unknownKind(rawKind)
        }
        let flags = UInt16(buffer[start + 6]) << 8 | UInt16(buffer[start + 7])
        guard flags & ~SPLKFraming.continuesFlag == 0 else {
            throw SPLKFrameError.unknownFlags(flags)
        }
        let length = Int(readUInt32(at: start + 8))
        guard length <= maxFramePayload else {
            throw SPLKFrameError.frameTooLarge(length)
        }
        return (kind, flags & SPLKFraming.continuesFlag != 0, length)
    }

    private func readUInt32(at index: Data.Index) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 << 8 | UInt32(buffer[index + $1]) }
    }
}

#endif
