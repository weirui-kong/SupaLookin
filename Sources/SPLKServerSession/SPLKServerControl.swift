//
//  SPLKServerControl.swift
//  SPLKServerSession
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SERVER

import Foundation
import SPLKProtocol
import SPLKModelBridge

enum SPLKServerTopic {
    static let appState = "app_state"
    static let screen = "screen"
    static let control = "control"
    static let hierarchyChanged = "hierarchy_changed"
    static let idle = "idle"
}

enum SPLKControlReason {
    static let leaseHeld = "lease_held"
    static let leaseRequired = "lease_required"
    static let leaseRevoked = "lease_revoked"
}

struct SPLKLease: Sendable {
    let id: Data
    let kind: SPLKV2AcquireControl.Kind
    let label: String
    let sessionID: Data

    var message: SPLKV2ControlLease {
        var message = SPLKV2ControlLease()
        message.leaseID = id
        message.kind = kind
        message.holderLabel = label
        return message
    }
}

// Lease and subscription state shared by the request handler (any thread) and the runtime (main actor).
final class SPLKServerState: @unchecked Sendable {

    private let lock = NSLock()
    private var active = false
    private var lease: SPLKLease?
    private var screen: SPLKV2ScreenInfo?
    private var generation: UInt64 = 1
    private var subscribers: [UUID: (topics: Set<String>, continuation: AsyncThrowingStream<SPLKV2StreamItem, Error>.Continuation)] = [:]

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    var isActive: Bool {
        locked { active }
    }

    func setActive(_ isActive: Bool) {
        let changed = locked { () -> Bool in
            defer { active = isActive }
            return active != isActive
        }
        if changed {
            publish(SPLKServerTopic.appState, Self.event { $0.appInForeground = isActive })
        }
    }

    func setScreen(_ screen: SPLKV2ScreenInfo) {
        let changed = locked { () -> Bool in
            defer { self.screen = screen }
            return self.screen != screen
        }
        if changed {
            publish(SPLKServerTopic.screen, Self.event { $0.screen = screen })
        }
    }

    // MARK: - Leases

    func authorize(_ request: SPLKV2Request, session: Data) throws {
        guard let call = request.call, call.isMutating else { return }
        let current = locked { lease }
        switch (current, request.leaseID.isEmpty) {
        case (nil, true):
            return
        case (nil, false):
            throw SPLKStatusError(.permissionDenied, reason: SPLKControlReason.leaseRevoked)
        case (.some, true):
            throw SPLKStatusError(.permissionDenied, reason: SPLKControlReason.leaseRequired)
        case (.some(let lease), false):
            guard lease.id == request.leaseID else {
                throw SPLKStatusError(.permissionDenied, reason: SPLKControlReason.leaseRevoked)
            }
        }
    }

    func acquire(_ call: SPLKV2AcquireControl, session: Data) throws -> SPLKLease {
        let new = SPLKLease(id: Data((0..<16).map { _ in UInt8.random(in: .min ... .max) }), kind: call.kind, label: call.holderLabel, sessionID: session)
        let previous: SPLKLease? = try locked {
            if lease != nil && !call.preempt {
                throw SPLKStatusError(.failedPrecondition, reason: SPLKControlReason.leaseHeld)
            }
            defer { lease = new }
            return lease
        }
        if let previous {
            publish(SPLKServerTopic.control, Self.event { $0.leaseReleased = previous.message })
        }
        publish(SPLKServerTopic.control, Self.event { $0.leaseAcquired = new.message })
        return new
    }

    func release(leaseID: Data) {
        releaseLease { $0.id == leaseID }
    }

    func sessionEnded(_ session: Data) {
        releaseLease { $0.sessionID == session }
    }

    private func releaseLease(where matches: (SPLKLease) -> Bool) {
        let released: SPLKLease? = locked {
            guard let current = lease, matches(current) else { return nil }
            lease = nil
            return current
        }
        if let released {
            publish(SPLKServerTopic.control, Self.event { $0.leaseReleased = released.message })
        }
    }

    // MARK: - Events

    func subscribe(_ topics: Set<String>) -> AsyncThrowingStream<SPLKV2StreamItem, Error> {
        let (stream, continuation) = AsyncThrowingStream<SPLKV2StreamItem, Error>.makeStream()
        let id = UUID()
        let (current, currentLease, currentScreen, currentGeneration) = locked { () -> (Bool, SPLKLease?, SPLKV2ScreenInfo?, UInt64) in
            subscribers[id] = (topics, continuation)
            return (active, lease, screen, generation)
        }
        continuation.onTermination = { [weak self] _ in
            self?.locked { _ = self?.subscribers.removeValue(forKey: id) }
        }
        // Each topic starts with its current state.
        if topics.contains(SPLKServerTopic.appState) {
            continuation.yield(Self.item(Self.event { $0.appInForeground = current }))
        }
        if topics.contains(SPLKServerTopic.screen), let currentScreen {
            continuation.yield(Self.item(Self.event { $0.screen = currentScreen }))
        }
        if topics.contains(SPLKServerTopic.hierarchyChanged) {
            continuation.yield(Self.item(Self.event { $0.hierarchyChangedVersion = currentGeneration }))
        }
        if topics.contains(SPLKServerTopic.control), let currentLease {
            continuation.yield(Self.item(Self.event { $0.leaseAcquired = currentLease.message }))
        }
        return stream
    }

    var wantsUIEvents: Bool {
        locked { subscribers.values.contains { !$0.topics.isDisjoint(with: [SPLKServerTopic.hierarchyChanged, SPLKServerTopic.idle]) } }
    }

    func publishHierarchyChanged(_ generation: UInt64) {
        locked { self.generation = generation }
        publish(SPLKServerTopic.hierarchyChanged, Self.event { $0.hierarchyChangedVersion = generation })
    }

    func publishIdle() {
        publish(SPLKServerTopic.idle, Self.event { $0.idle = SPLKV2Empty() })
    }

    private func publish(_ topic: String, _ event: SPLKV2Event) {
        let targets = locked { subscribers.values.filter { $0.topics.contains(topic) }.map(\.continuation) }
        targets.forEach { $0.yield(Self.item(event)) }
    }

    private static func event(_ build: (inout SPLKV2Event) -> Void) -> SPLKV2Event {
        var event = SPLKV2Event()
        build(&event)
        return event
    }

    private static func item(_ event: SPLKV2Event) -> SPLKV2StreamItem {
        var item = SPLKV2StreamItem()
        item.event = event
        return item
    }
}

#endif
