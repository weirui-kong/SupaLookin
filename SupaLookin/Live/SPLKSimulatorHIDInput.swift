//
//  SPLKSimulatorHIDInput.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
@preconcurrency import XPC
import SPLKProtocol

// Sends touches and buttons into a simulator through dtuhidd, the HID daemon Xcode 27 runs in it (private).
// The protocol follows facebook/idb's FBSimulatorControl/HID (MIT).
nonisolated final class SPLKSimulatorHIDInput: SPLKHostInput, @unchecked Sendable {

    typealias Button = SPLKHostButton

    static let service = "com.apple.coredevice.feature.remote.hid.digitizer"
    static let barrierTimeout: TimeInterval = 4
    static let barrierAttempts = 5

    // dtuhidd arrived with CoreSimulator 1155.4; older ones only take Indigo, which M9 doesn't speak.
    static var isSupported: Bool {
        guard let version = SPLKSimulatorDisplay.coreSimulatorVersion else { return false }
        return isSupported(version: version)
    }

    static func isSupported(version: String) -> Bool {
        version.compare("1155.4", options: .numeric) != .orderedAscending
    }

    let udid: String?
    private let queue = DispatchQueue(label: "SPLKSimulatorHIDInput")
    private var connection: xpc_connection_t?
    private var translator = SPLKDigitizerTranslator()

    init(udid: String?) {
        self.udid = udid
    }

    // MARK: - Sending

    // Touch events only; anything else in `events` is ignored.
    func send(_ events: [SPLKV2InputEvent], orientation: SPLKV2ScreenInfo.Orientation) async throws {
        try await perform { input in
            let connection = try input.connectedConnection(attempts: 1)
            for message in input.translator.translate(events) {
                let points = message.points.map { SPLKDigitizerTranslator.nativePoint($0, orientation: orientation) }
                xpc_connection_send_message(connection, Self.digitizer(points, eventType: message.eventType))
            }
        }
    }

    func press(_ button: Button) async throws {
        try await perform { input in
            let connection = try input.connectedConnection(attempts: 1)
            for state: UInt64 in [1, 2] {
                xpc_connection_send_message(connection, Self.button(button, state: state))
                if state == 1 {
                    Thread.sleep(forTimeInterval: Double(button.holdMilliseconds) / 1000)
                }
            }
        }
    }

    // Connects now, so a failure can pick another backend before any input is lost.
    func connect() async throws {
        try await perform { input in
            _ = try input.connectedConnection(attempts: Self.barrierAttempts)
        }
    }

    private func perform(_ body: @escaping @Sendable (SPLKSimulatorHIDInput) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try body(self)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Connection

    // Input already flowing retries once, so a dead daemon can't stall it for long.
    private func connectedConnection(attempts: Int) throws -> xpc_connection_t {
        if let connection {
            return connection
        }
        var lastError: Error = SPLKVideoError(NSLocalizedString("The simulator's input service didn't answer.", comment: ""))
        for attempt in 0..<attempts {
            if attempt > 0 {
                // launchd throttles dtuhidd's respawn for its 10 s minimum runtime.
                Thread.sleep(forTimeInterval: Self.barrierTimeout)
            }
            do {
                let connection = try makeConnection()
                if try barrier(connection) {
                    // idb waits this long after the first reply before sending input.
                    Thread.sleep(forTimeInterval: 0.2)
                    self.connection = connection
                    translator = SPLKDigitizerTranslator()
                    return connection
                }
                xpc_connection_cancel(connection)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func makeConnection() throws -> xpc_connection_t {
        typealias CreateEndpoint = @convention(c) (mach_port_t, UInt64, UInt64) -> xpc_endpoint_t?
        typealias EnableSim2Host = @convention(c) (xpc_connection_t) -> Void
        let handle = dlopen(nil, RTLD_NOW)
        guard let createSymbol = dlsym(handle, "xpc_endpoint_create_mach_port_4sim"),
              let enableSymbol = dlsym(handle, "xpc_connection_enable_sim2host_4sim") else {
            throw SPLKVideoError(NSLocalizedString("This macOS can't send input into simulators.", comment: ""))
        }
        let createEndpoint = unsafeBitCast(createSymbol, to: CreateEndpoint.self)
        let enableSim2Host = unsafeBitCast(enableSymbol, to: EnableSim2Host.self)

        let device = try SPLKSimulatorDisplay.bootedDevice(udid: udid)
        let port = try Self.lookup(Self.service, on: device)
        guard let endpoint = createEndpoint(port, 0, 0) else {
            throw SPLKVideoError(NSLocalizedString("The simulator's input service didn't answer.", comment: ""))
        }
        let connection = xpc_connection_create_from_endpoint(endpoint)
        // Without this the daemon sees the peer but never a payload.
        enableSim2Host(connection)
        xpc_connection_set_target_queue(connection, queue)
        let identifier = ObjectIdentifier(connection)
        xpc_connection_set_event_handler(connection) { [weak self] event in
            guard xpc_get_type(event) == XPC_TYPE_ERROR else { return }
            // Called on `queue`; the next send reconnects and proves the daemon again.
            if let self, self.connection.map(ObjectIdentifier.init) == identifier {
                self.connection = nil
            }
        }
        xpc_connection_resume(connection)
        return connection
    }

    private static func lookup(_ service: String, on device: NSObject) throws -> mach_port_t {
        let selector = NSSelectorFromString("lookup:error:")
        guard device.responds(to: selector) else {
            throw SPLKVideoError(NSLocalizedString("This Xcode can't send input into simulators.", comment: ""))
        }
        typealias Lookup = @convention(c) (NSObject, Selector, NSString, UnsafeMutablePointer<NSError?>?) -> mach_port_t
        var error: NSError?
        let port = unsafeBitCast(device.method(for: selector), to: Lookup.self)(device, selector, service as NSString, &error)
        guard port != MACH_PORT_NULL else {
            throw SPLKVideoError(NSLocalizedString("The simulator's input service didn't answer.", comment: ""), error?.localizedDescription)
        }
        return port
    }

    // A lookup succeeds even when dtuhidd can't run, so only a reply proves it's there.
    private func barrier(_ connection: xpc_connection_t) throws -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var answered = false
        let message = Self.envelope("IndigoKeyboardButtonEvent", isBarrier: true, payload: Self.dictionary(["usageCode": 0, "state": 2]))
        xpc_connection_send_message_with_reply(connection, message, DispatchQueue.global()) { reply in
            answered = xpc_get_type(reply) != XPC_TYPE_ERROR
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + Self.barrierTimeout) == .success else {
            return false
        }
        return answered
    }

    // MARK: - Messages

    private static func envelope(_ type: String, isBarrier: Bool = false, payload: xpc_object_t) -> xpc_object_t {
        let message = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(message, "messageType", type)
        xpc_dictionary_set_bool(message, "isBarrier", isBarrier)
        xpc_dictionary_set_string(message, "featureIdentifier", service)
        xpc_dictionary_set_value(message, "payload", payload)
        return message
    }

    private static func dictionary(_ values: [String: UInt64]) -> xpc_object_t {
        let dictionary = xpc_dictionary_create(nil, nil, 0)
        for (key, value) in values {
            xpc_dictionary_set_uint64(dictionary, key, value)
        }
        return dictionary
    }

    private static func point(_ point: CGPoint) -> xpc_object_t {
        let dictionary = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_double(dictionary, "x", point.x)
        xpc_dictionary_set_double(dictionary, "y", point.y)
        return dictionary
    }

    private static func digitizer(_ points: [CGPoint], eventType: UInt64) -> xpc_object_t {
        let payload = dictionary(["eventType": eventType, "edge": 0, "target": 0])
        if let first = points.first {
            xpc_dictionary_set_value(payload, "pointOne", point(first))
        }
        if points.count > 1 {
            xpc_dictionary_set_value(payload, "pointTwo", point(points[1]))
        }
        return envelope("IndigoDigitizerEvent", payload: payload)
    }

    private static func button(_ button: Button, state: UInt64) -> xpc_object_t {
        return envelope("IndigoButtonEvent", payload: dictionary(["usagePage": UInt64(button.usagePage), "usageCode": UInt64(button.usage), "state": state]))
    }
}

// Turns InjectInput touches into dtuhidd's digitizer messages, which carry up to two fingers and no finger IDs.
nonisolated struct SPLKDigitizerTranslator {

    static let start: UInt64 = 0
    static let position: UInt64 = 1
    static let end: UInt64 = 2

    struct Message: Equatable {
        let eventType: UInt64
        let points: [CGPoint]
    }

    private var live: [UInt32: CGPoint] = [:]

    private enum Kind {
        case began, moved, ended
    }

    mutating func translate(_ events: [SPLKV2InputEvent]) -> [Message] {
        var messages: [Message] = []
        var group: [(UInt32, Kind, CGPoint)] = []
        for event in events {
            guard case .touch(let touch) = event.kind else { continue }
            let kind: Kind
            switch touch.phase {
            case .began: kind = .began
            case .moved, .stationary: kind = .moved
            case .ended, .cancelled: kind = .ended
            default: continue
            }
            let location = CGPoint(x: touch.location.x, y: touch.location.y)
            // A run of one phase becomes one message; a repeated finger starts the next.
            if let last = group.last, last.1 != kind || group.contains(where: { $0.0 == touch.touchID }) {
                messages += flush(group)
                group = []
            }
            group.append((touch.touchID, kind, location))
        }
        messages += flush(group)
        return messages
    }

    private mutating func flush(_ group: [(UInt32, Kind, CGPoint)]) -> [Message] {
        guard let kind = group.first?.1 else { return [] }
        switch kind {
        case .began:
            let wasIdle = live.isEmpty
            for (id, _, location) in group {
                live[id] = location
            }
            return [Message(eventType: wasIdle ? Self.start : Self.position, points: livePoints())]
        case .moved:
            let known = group.filter { live[$0.0] != nil }
            guard !known.isEmpty else { return [] }
            for (id, _, location) in known {
                live[id] = location
            }
            return [Message(eventType: Self.position, points: livePoints())]
        case .ended:
            let known = group.filter { live[$0.0] != nil }
            guard !known.isEmpty else { return [] }
            for (id, _, _) in known {
                live[id] = nil
            }
            if live.isEmpty {
                return [Message(eventType: Self.end, points: Array(known.sorted { $0.0 < $1.0 }.map(\.2).prefix(2)))]
            }
            return [Message(eventType: Self.position, points: livePoints())]
        }
    }

    private func livePoints() -> [CGPoint] {
        Array(live.sorted { $0.key < $1.key }.map(\.value).prefix(2))
    }

    // The digitizer counts in the display's native portrait frame; InjectInput counts in the interface orientation.
    static func nativePoint(_ point: CGPoint, orientation: SPLKV2ScreenInfo.Orientation) -> CGPoint {
        switch orientation {
        case .landscapeLeft: return CGPoint(x: point.y, y: 1 - point.x)
        case .landscapeRight: return CGPoint(x: 1 - point.y, y: point.x)
        case .portraitUpsideDown: return CGPoint(x: 1 - point.x, y: 1 - point.y)
        default: return point
        }
    }
}
