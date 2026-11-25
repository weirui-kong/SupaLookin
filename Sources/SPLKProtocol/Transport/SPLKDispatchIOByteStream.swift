//
//  SPLKDispatchIOByteStream.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation

public final class SPLKDispatchIOByteStream: SPLKByteStream {

    public let incoming: AsyncThrowingStream<Data, Error>
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private let channel: DispatchIO
    private let queue: DispatchQueue

    // usbmux hands over an already connected stream channel, so this takes the channel rather than a socket.
    public init(channel: DispatchIO, queue: DispatchQueue = DispatchQueue(label: "SPLKDispatchIOByteStream")) {
        (incoming, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
        self.channel = channel
        self.queue = queue
        channel.setLimit(lowWater: 1)
        let continuation = continuation
        channel.read(offset: 0, length: Int.max, queue: queue) { done, data, error in
            if let data, !data.isEmpty {
                continuation.yield(Data(data))
            }
            guard done else { return }
            if error != 0 && error != ECANCELED {
                continuation.finish(throwing: POSIXError(POSIXErrorCode(rawValue: error) ?? .EIO))
            } else {
                continuation.finish()
            }
        }
    }

    // Takes ownership of `fileDescriptor`, which is closed with the stream.
    public convenience init(fileDescriptor: Int32) {
        let queue = DispatchQueue(label: "SPLKDispatchIOByteStream")
        let channel = DispatchIO(type: .stream, fileDescriptor: fileDescriptor, queue: queue) { _ in
            Darwin.close(fileDescriptor)
        }
        self.init(channel: channel, queue: queue)
    }

    public func send(_ data: Data) async throws {
        let dispatchData = data.withUnsafeBytes { DispatchData(bytes: $0) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            channel.write(offset: 0, data: dispatchData, queue: queue) { done, _, error in
                guard done else { return }
                if error != 0 {
                    continuation.resume(throwing: POSIXError(POSIXErrorCode(rawValue: error) ?? .EIO))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func close() {
        channel.close(flags: .stop)
        continuation.finish()
    }
}
