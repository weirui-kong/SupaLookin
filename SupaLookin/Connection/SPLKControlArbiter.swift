//
//  SPLKControlArbiter.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Combine
import SPLKProtocol

protocol SPLKControlChannel: AnyObject {
    func acquireControl(kind: SPLKV2AcquireControl.Kind, holderLabel: String, preempt: Bool) async throws -> SPLKV2ControlLease
    func releaseControl(_ leaseID: Data) async throws
    func events(topics: [String]) async throws -> AsyncThrowingStream<SPLKV2StreamItem, Error>
}

// Decides who may change the phone: the window, Live Control, or the one MCP session in takeover.
final class SPLKControlArbiter {

    enum Mode: Equatable {
        case inspect
        case liveControl
        case takeover(session: String, label: String)
    }

    enum Actor: Equatable {
        case window
        case mcp(String)
    }

    struct ActionLogEntry: Equatable {
        let session: String
        let method: String
        let date: Date
    }

    enum Reason {
        static let takeoverActive = "takeover_active"
        static let leaseRequired = "lease_required"
        static let leaseHeld = "lease_held"
    }

    static let renewalTimeout: TimeInterval = 30

    let modeSubject = CurrentValueSubject<Mode, Never>(.inspect)
    let actionLog = PassthroughSubject<ActionLogEntry, Never>()

    private(set) var mode = Mode.inspect {
        didSet { modeSubject.send(mode) }
    }

    private weak var channel: SPLKControlChannel?
    private let now: () -> Date
    private var lease: SPLKV2ControlLease?
    private var lastRenewal = Date.distantPast
    private var watcher: Task<Void, Never>?
    private var expiryTimer: Task<Void, Never>?

    init(channel: SPLKControlChannel, now: @escaping () -> Date = Date.init) {
        self.channel = channel
        self.now = now
    }

    // MARK: - Live Control

    func startLiveControl() async throws {
        switch mode {
        case .liveControl:
            return
        case .takeover:
            throw Self.denied(Reason.takeoverActive)
        case .inspect:
            try await acquire(kind: .liveControl, label: "Supa Lookin", preempt: false)
            mode = .liveControl
        }
    }

    func stopLiveControl() async {
        guard mode == .liveControl else { return }
        await releaseLease()
        mode = .inspect
    }

    // MARK: - Takeover

    func requestTakeover(session: String, label: String) async throws {
        if case .takeover(let holder, _) = mode {
            guard holder == session else {
                throw SPLKStatusError(.failedPrecondition, reason: Reason.leaseHeld,
                                      title: NSLocalizedString("Another agent is controlling this app.", comment: ""),
                                      detail: NSLocalizedString("Wait until it releases control, or take back control in Supa Lookin.", comment: ""))
            }
            lastRenewal = now()
            return
        }
        try await acquire(kind: .takeover, label: label, preempt: true)
        lastRenewal = now()
        mode = .takeover(session: session, label: label)
        startExpiryTimer()
    }

    func renewTakeover(session: String) throws {
        guard case .takeover(let holder, _) = mode, holder == session else {
            throw Self.denied(Reason.leaseRequired)
        }
        lastRenewal = now()
    }

    func releaseTakeover(session: String) async {
        guard case .takeover(let holder, _) = mode, holder == session else { return }
        await endTakeover()
    }

    // The person at the Mac always wins.
    func takeBack() async {
        guard case .takeover = mode else { return }
        await endTakeover()
    }

    func expireIfNeeded() async {
        guard case .takeover = mode, now().timeIntervalSince(lastRenewal) >= Self.renewalTimeout else { return }
        await endTakeover()
    }

    private func endTakeover() async {
        expiryTimer?.cancel()
        expiryTimer = nil
        await releaseLease()
        mode = .inspect
    }

    private func startExpiryTimer() {
        expiryTimer?.cancel()
        expiryTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await self?.expireIfNeeded()
            }
        }
    }

    // MARK: - Authorization

    // The lease ID a mutating call from `actor` carries, or the refusal it gets.
    func leaseID(for actor: Actor, method: String) throws -> Data {
        switch (actor, mode) {
        case (.window, .inspect):
            return Data()
        case (.window, .liveControl):
            return lease?.leaseID ?? Data()
        case (.window, .takeover):
            throw Self.denied(Reason.takeoverActive)
        case (.mcp(let session), .takeover(let holder, _)) where session == holder:
            actionLog.send(ActionLogEntry(session: session, method: method, date: now()))
            return lease?.leaseID ?? Data()
        case (.mcp, _):
            throw Self.denied(Reason.leaseRequired)
        }
    }

    private static func denied(_ reason: String) -> SPLKStatusError {
        switch reason {
        case Reason.takeoverActive:
            return SPLKStatusError(.permissionDenied, reason: reason,
                                   title: NSLocalizedString("An agent is controlling this app.", comment: ""),
                                   detail: NSLocalizedString("Take back control in Supa Lookin to make changes.", comment: ""))
        default:
            return SPLKStatusError(.permissionDenied, reason: reason,
                                   title: NSLocalizedString("Take over the app before changing it.", comment: ""),
                                   detail: "")
        }
    }

    // MARK: - Phone lease

    private func acquire(kind: SPLKV2AcquireControl.Kind, label: String, preempt: Bool) async throws {
        guard let channel else {
            throw SPLKStatusError(.unavailable)
        }
        let previous = lease
        let newLease = try await channel.acquireControl(kind: kind, holderLabel: label, preempt: preempt)
        lease = newLease
        if previous == nil {
            watchPhoneLease()
        }
    }

    private func releaseLease() async {
        guard let current = lease else { return }
        lease = nil
        watcher?.cancel()
        watcher = nil
        try? await channel?.releaseControl(current.leaseID)
    }

    // The phone ends a lease on its own when the session closes or another client preempts it.
    private func watchPhoneLease() {
        watcher?.cancel()
        watcher = Task { [weak self] in
            guard let events = try? await self?.channel?.events(topics: ["control"]) else { return }
            do {
                for try await item in events {
                    if case .leaseReleased(let released) = item.event.kind {
                        self?.phoneReleased(released.leaseID)
                    }
                }
            } catch {}
        }
    }

    func phoneReleased(_ leaseID: Data) {
        guard lease?.leaseID == leaseID else { return }
        lease = nil
        expiryTimer?.cancel()
        expiryTimer = nil
        watcher?.cancel()
        watcher = nil
        mode = .inspect
    }
}
