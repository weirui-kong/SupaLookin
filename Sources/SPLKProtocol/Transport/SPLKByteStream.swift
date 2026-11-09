//
//  SPLKByteStream.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SHARED

import Foundation

// `incoming` has a single consumer: the connection that reads frames from it.
public protocol SPLKByteStream: AnyObject, Sendable {
    var incoming: AsyncThrowingStream<Data, Error> { get }
    func send(_ data: Data) async throws
    func close()
}

public enum SPLKTransportError: Error, Equatable {
    case closed
    case timedOut
    case failed(String)
}

final class SPLKLocked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

public final class SPLKMemoryByteStream: SPLKByteStream {

    private final class Link: Sendable {
        let continuations: [AsyncThrowingStream<Data, Error>.Continuation]
        let closed = SPLKLocked(false)

        init(_ continuations: [AsyncThrowingStream<Data, Error>.Continuation]) {
            self.continuations = continuations
        }

        func close() {
            let wasClosed = closed.withLock { closed in
                defer { closed = true }
                return closed
            }
            if !wasClosed {
                continuations.forEach { $0.finish() }
            }
        }
    }

    public let incoming: AsyncThrowingStream<Data, Error>
    private let link: Link
    private let peerIndex: Int

    private init(incoming: AsyncThrowingStream<Data, Error>, link: Link, peerIndex: Int) {
        self.incoming = incoming
        self.link = link
        self.peerIndex = peerIndex
    }

    public static func pair() -> (SPLKMemoryByteStream, SPLKMemoryByteStream) {
        let (first, firstContinuation) = AsyncThrowingStream<Data, Error>.makeStream()
        let (second, secondContinuation) = AsyncThrowingStream<Data, Error>.makeStream()
        let link = Link([firstContinuation, secondContinuation])
        return (
            SPLKMemoryByteStream(incoming: first, link: link, peerIndex: 1),
            SPLKMemoryByteStream(incoming: second, link: link, peerIndex: 0)
        )
    }

    public func send(_ data: Data) async throws {
        try link.closed.withLock { closed in
            guard !closed else {
                throw SPLKTransportError.closed
            }
            link.continuations[peerIndex].yield(data)
        }
    }

    public func close() {
        link.close()
    }
}

#endif
