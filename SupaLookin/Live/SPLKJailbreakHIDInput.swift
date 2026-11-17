//
//  SPLKJailbreakHIDInput.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/18.
//

import Foundation
import Security
import SPLKProtocol
import SPLKServer

// Drives splkhidd, the helper a jailbroken device runs for Supa Lookin, over usbmux. See
// spec/20261118-protocol-v2-m12-jailbreak-input.md.
actor SPLKJailbreakHIDInput: SPLKHostInput {

    static let port: Int32 = 47290
    static let tokenDirectory = "/SupaLookin"
    static let tokenFile = "splkhid-token"
    static let greetingTimeout: TimeInterval = 2

    // Why the helper refused, or couldn't be reached.
    struct Refusal: Error, Equatable {
        let reason: String

        static let locked = Refusal(reason: "locked")
        static let unreachable = Refusal(reason: "unreachable")
    }

    nonisolated let udid: String
    nonisolated let deviceID: NSNumber
    // Called with true when the device locks during a session, and false when it unlocks.
    private let onLockChange: @Sendable (Bool) -> Void

    private var stream: SPLKByteStream?
    private var reader: Task<Void, Never>?
    private var encoder = SPLKTouchFrameEncoder()

    init(udid: String, deviceID: NSNumber, onLockChange: @escaping @Sendable (Bool) -> Void) {
        self.udid = udid
        self.deviceID = deviceID
        self.onLockChange = onLockChange
    }

    func connect() async throws {
        if stream != nil {
            return
        }
        let token = try Self.makeToken()
        try await SPLKMobileDeviceAFC.write(Data(token.utf8), toDirectory: Self.tokenDirectory, file: Self.tokenFile, udid: udid)
        let stream: SPLKByteStream
        do {
            stream = try await Self.openUSB(deviceID: deviceID, port: Self.port)
        } catch {
            throw Refusal.unreachable
        }
        try await stream.send(Data("HELLO 1 \(token)\n".utf8))

        // One reader takes the greeting, then the STATE lines that follow it.
        let onLockChange = self.onLockChange
        let greeting = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            let once = SPLKResumeOnce(continuation)
            reader = Task { [weak self] in
                var lines = SPLKLineReader(stream.incoming)
                let first = try? await lines.next()
                once.resume(first)
                guard first == "SPLKHID 1 OK" else { return }
                do {
                    while let line = try await lines.next() {
                        switch line {
                        case "STATE locked": onLockChange(true)
                        case "STATE unlocked": onLockChange(false)
                        default: break
                        }
                    }
                } catch {}
                await self?.connectionEnded(stream)
            }
            Task {
                try? await Task.sleep(for: .seconds(Self.greetingTimeout))
                once.resume(nil)
            }
        }
        guard greeting == "SPLKHID 1 OK" else {
            reader?.cancel()
            reader = nil
            stream.close()
            let prefix = "SPLKHID 1 ERROR "
            if let greeting, greeting.hasPrefix(prefix) {
                throw Refusal(reason: String(greeting.dropFirst(prefix.count)))
            }
            throw Refusal.unreachable
        }
        self.stream = stream
        encoder = SPLKTouchFrameEncoder()
    }

    func send(_ events: [SPLKV2InputEvent], orientation: SPLKV2ScreenInfo.Orientation) async throws {
        let frames = encoder.frames(for: events) { SPLKDigitizerTranslator.nativePoint($0, orientation: orientation) }
        guard !frames.isEmpty else { return }
        try await write(frames.map(SPLKTouchFrameEncoder.line(for:)))
    }

    func press(_ button: SPLKHostButton) async throws {
        try await write([SPLKTouchFrameEncoder.buttonLine(page: button.usagePage, usage: button.usage, holdMilliseconds: button.holdMilliseconds)])
    }

    func disconnect() {
        reader?.cancel()
        reader = nil
        stream?.close()
        stream = nil
    }

    // A broken connection is reopened once, with a fresh token.
    private func write(_ lines: [String]) async throws {
        let data = Data(lines.map { $0 + "\n" }.joined().utf8)
        if let stream {
            do {
                try await stream.send(data)
                return
            } catch {
                disconnect()
            }
        }
        try await connect()
        try await stream?.send(data)
    }

    private func connectionEnded(_ ended: SPLKByteStream) {
        if stream === ended {
            stream = nil
            reader = nil
        }
    }

    private static func makeToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw Refusal(reason: "random")
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func openUSB(deviceID: NSNumber, port: Int32) async throws -> SPLKByteStream {
        try await withCheckedThrowingContinuation { continuation in
            SPLK_PTUSBHub.shared().connect(toDevice: deviceID, port: port, onStart: { error, channel in
                if let error {
                    continuation.resume(throwing: error)
                } else if let channel {
                    continuation.resume(returning: SPLKDispatchIOByteStream(channel: channel))
                } else {
                    continuation.resume(throwing: SPLKTransportError.closed)
                }
            }, onEnd: nil)
        }
    }
}

// Resumes a continuation with the first value offered; later ones are dropped.
nonisolated final class SPLKResumeOnce<Value: Sendable>: @unchecked Sendable {

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Value) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }
}

// Splits a byte stream into newline-terminated lines.
nonisolated struct SPLKLineReader: @unchecked Sendable {

    private var iterator: AsyncThrowingStream<Data, Error>.AsyncIterator
    private var buffer = Data()

    init(_ stream: AsyncThrowingStream<Data, Error>) {
        iterator = stream.makeAsyncIterator()
    }

    mutating func next() async throws -> String? {
        while true {
            if let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                return String(decoding: line, as: UTF8.self)
            }
            guard let chunk = try await iterator.next() else {
                return nil
            }
            buffer.append(chunk)
        }
    }
}
