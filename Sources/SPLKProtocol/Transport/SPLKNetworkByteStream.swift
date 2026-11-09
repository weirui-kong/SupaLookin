//
//  SPLKNetworkByteStream.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SHARED

import Foundation
import Network

public final class SPLKNetworkByteStream: SPLKByteStream {

    public let incoming: AsyncThrowingStream<Data, Error>
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private let connection: NWConnection

    private init(readyConnection connection: NWConnection) {
        (incoming, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
        self.connection = connection
        connection.stateUpdateHandler = { [continuation] state in
            switch state {
            case .failed(let error):
                continuation.finish(throwing: error)
            case .cancelled:
                continuation.finish()
            default:
                break
            }
        }
        receive()
    }

    static func tcpParameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        return NWParameters(tls: nil, tcp: tcp)
    }

    public static func connect(host: String, port: UInt16, timeout: TimeInterval) async throws -> SPLKNetworkByteStream {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw SPLKTransportError.failed("invalid port \(port)")
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: tcpParameters())
        return try await open(connection, timeout: timeout)
    }

    // Starts a connection, from `connect` or accepted by a listener, and wraps it once it's ready.
    static func open(_ connection: NWConnection, timeout: TimeInterval) async throws -> SPLKNetworkByteStream {
        let queue = DispatchQueue(label: "SPLKNetworkByteStream")
        let resumed = SPLKLocked(false)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SPLKNetworkByteStream, Error>) in
            let finish: @Sendable (Result<SPLKNetworkByteStream, Error>) -> Void = { result in
                let first = resumed.withLock { resumed in
                    defer { resumed = true }
                    return !resumed
                }
                guard first else { return }
                if case .failure = result {
                    connection.cancel()
                }
                continuation.resume(with: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.success(SPLKNetworkByteStream(readyConnection: connection)))
                case .failed(let error):
                    finish(.failure(error))
                case .waiting(let error):
                    // A refused loopback connection waits forever for a route instead of failing.
                    finish(.failure(error))
                case .cancelled:
                    finish(.failure(SPLKTransportError.closed))
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(SPLKTransportError.timedOut))
            }
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                continuation.yield(data)
            }
            if let error {
                continuation.finish(throwing: error)
                connection.cancel()
            } else if isComplete {
                continuation.finish()
                connection.cancel()
            } else {
                receive()
            }
        }
    }

    public func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    public func close() {
        connection.cancel()
        continuation.finish()
    }
}

public final class SPLKListener: Sendable {

    public let port: UInt16
    public let connections: AsyncStream<SPLKNetworkByteStream>
    private let listener: NWListener
    private let continuation: AsyncStream<SPLKNetworkByteStream>.Continuation

    private init(listener: NWListener, port: UInt16) {
        self.listener = listener
        self.port = port
        (connections, continuation) = AsyncStream<SPLKNetworkByteStream>.makeStream()
        listener.newConnectionHandler = { [continuation] connection in
            Task {
                if let stream = try? await SPLKNetworkByteStream.open(connection, timeout: 2) {
                    continuation.yield(stream)
                }
            }
        }
        listener.stateUpdateHandler = { [continuation] state in
            switch state {
            case .failed, .cancelled:
                continuation.finish()
            default:
                break
            }
        }
    }

    // Binds the first free port of `ports` on 127.0.0.1, or a system-assigned port when `ports` is nil.
    public static func bind(ports: ClosedRange<UInt16>?) async throws -> SPLKListener {
        let candidates: [UInt16] = ports.map(Array.init) ?? [0]
        var lastError: Error = SPLKTransportError.failed("no port to bind")
        for port in candidates {
            do {
                return try await bind(port: port)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func bind(port: UInt16) async throws -> SPLKListener {
        let parameters = SPLKNetworkByteStream.tcpParameters()
        let requestedPort = NWEndpoint.Port(rawValue: port) ?? .any
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: requestedPort)
        let listener = try NWListener(using: parameters)
        let queue = DispatchQueue(label: "SPLKListener")
        let resumed = SPLKLocked(false)
        let boundPort: UInt16 = try await withCheckedThrowingContinuation { continuation in
            let finish: @Sendable (Result<UInt16, Error>) -> Void = { result in
                let first = resumed.withLock { resumed in
                    defer { resumed = true }
                    return !resumed
                }
                guard first else { return }
                if case .failure = result {
                    listener.cancel()
                }
                continuation.resume(with: result)
            }
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.success(listener.port?.rawValue ?? port))
                case .failed(let error), .waiting(let error):
                    finish(.failure(error))
                case .cancelled:
                    finish(.failure(SPLKTransportError.closed))
                default:
                    break
                }
            }
            listener.newConnectionHandler = { $0.cancel() }
            listener.start(queue: queue)
        }
        return SPLKListener(listener: listener, port: boundPort)
    }

    public func close() {
        listener.cancel()
        continuation.finish()
    }
}

#endif
