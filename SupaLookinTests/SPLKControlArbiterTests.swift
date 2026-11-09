//
//  SPLKControlArbiterTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Combine
import Testing
import SPLKProtocol
@testable import SupaLookin

private final class FakeChannel: SPLKControlChannel {
    var acquired: [(SPLKV2AcquireControl.Kind, Bool)] = []
    var released: [Data] = []
    private var counter: UInt8 = 0
    private var continuation: AsyncThrowingStream<SPLKV2StreamItem, Error>.Continuation?

    func acquireControl(kind: SPLKV2AcquireControl.Kind, holderLabel: String, preempt: Bool) async throws -> SPLKV2ControlLease {
        acquired.append((kind, preempt))
        counter += 1
        var lease = SPLKV2ControlLease()
        lease.leaseID = Data([counter])
        lease.kind = kind
        lease.holderLabel = holderLabel
        return lease
    }

    func releaseControl(_ leaseID: Data) async throws {
        released.append(leaseID)
    }

    func events(topics: [String]) async throws -> AsyncThrowingStream<SPLKV2StreamItem, Error> {
        let (stream, continuation) = AsyncThrowingStream<SPLKV2StreamItem, Error>.makeStream()
        self.continuation = continuation
        return stream
    }

    func phoneReleases(_ leaseID: Data) {
        var lease = SPLKV2ControlLease()
        lease.leaseID = leaseID
        var item = SPLKV2StreamItem()
        item.event.leaseReleased = lease
        continuation?.yield(item)
    }
}

private func reason(_ body: () throws -> Void) -> String? {
    do {
        try body()
        return nil
    } catch let error as SPLKStatusError {
        return error.reason
    } catch {
        return "\(error)"
    }
}

struct SPLKControlArbiterTests {

    @Test func inspectLetsOnlyTheWindowMutate() throws {
        let channel = FakeChannel()
        let arbiter = SPLKControlArbiter(channel: channel)
        #expect(try arbiter.leaseID(for: .window, method: "ModifyAttribute") == Data())
        #expect(reason { _ = try arbiter.leaseID(for: .mcp("a"), method: "ModifyAttribute") } == "lease_required")
    }

    @Test func liveControlHoldsTheWindowsLease() async throws {
        let channel = FakeChannel()
        let arbiter = SPLKControlArbiter(channel: channel)
        try await arbiter.startLiveControl()
        #expect(arbiter.mode == .liveControl)
        #expect(channel.acquired.first?.0 == .liveControl)
        #expect(try arbiter.leaseID(for: .window, method: "InjectInput") == Data([1]))

        await arbiter.stopLiveControl()
        #expect(arbiter.mode == .inspect)
        #expect(channel.released == [Data([1])])
    }

    @Test func takeoverPreemptsAndLocksOutTheWindow() async throws {
        let channel = FakeChannel()
        let arbiter = SPLKControlArbiter(channel: channel)
        try await arbiter.startLiveControl()
        try await arbiter.requestTakeover(session: "a", label: "Agent")
        #expect(arbiter.mode == .takeover(session: "a", label: "Agent"))
        #expect(channel.acquired.last.map { ($0.0, $0.1) } ?? (.unspecified, false) == (.takeover, true))
        #expect(reason { _ = try arbiter.leaseID(for: .window, method: "ModifyAttribute") } == "takeover_active")
        #expect(try arbiter.leaseID(for: .mcp("a"), method: "ModifyAttribute") == Data([2]))
        #expect(reason { _ = try arbiter.leaseID(for: .mcp("b"), method: "ModifyAttribute") } == "lease_required")
        await #expect(throws: SPLKStatusError.self) { try await arbiter.startLiveControl() }
    }

    @Test func secondTakeoverIsRefused() async throws {
        let channel = FakeChannel()
        let arbiter = SPLKControlArbiter(channel: channel)
        try await arbiter.requestTakeover(session: "a", label: "A")
        do {
            try await arbiter.requestTakeover(session: "b", label: "B")
            Issue.record("expected a refusal")
        } catch let error as SPLKStatusError {
            #expect(error.reason == "lease_held")
        }
        #expect(arbiter.mode == .takeover(session: "a", label: "A"))
    }

    @Test func unrenewedTakeoverExpires() async throws {
        var clock = Date(timeIntervalSince1970: 0)
        let channel = FakeChannel()
        let arbiter = SPLKControlArbiter(channel: channel, now: { clock })
        try await arbiter.requestTakeover(session: "a", label: "A")

        clock += 29
        await arbiter.expireIfNeeded()
        #expect(arbiter.mode == .takeover(session: "a", label: "A"))
        try arbiter.renewTakeover(session: "a")

        clock += 29
        await arbiter.expireIfNeeded()
        #expect(arbiter.mode == .takeover(session: "a", label: "A"))

        clock += 1
        await arbiter.expireIfNeeded()
        #expect(arbiter.mode == .inspect)
        #expect(channel.released == [Data([1])])
    }

    @Test func takeBackRevokesTheAgent() async throws {
        let channel = FakeChannel()
        let arbiter = SPLKControlArbiter(channel: channel)
        try await arbiter.requestTakeover(session: "a", label: "A")
        await arbiter.takeBack()
        #expect(arbiter.mode == .inspect)
        #expect(reason { _ = try arbiter.leaseID(for: .mcp("a"), method: "ModifyAttribute") } == "lease_required")
        #expect(try arbiter.leaseID(for: .window, method: "ModifyAttribute") == Data())
    }

    @Test func phoneEndingTheLeaseReturnsToInspect() async throws {
        let channel = FakeChannel()
        let arbiter = SPLKControlArbiter(channel: channel)
        try await arbiter.startLiveControl()
        try await Task.sleep(nanoseconds: 50_000_000)
        channel.phoneReleases(Data([1]))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(arbiter.mode == .inspect)
    }

    @Test func agentMutationsAreLogged() async throws {
        let channel = FakeChannel()
        let arbiter = SPLKControlArbiter(channel: channel)
        var entries: [SPLKControlArbiter.ActionLogEntry] = []
        let subscription = arbiter.actionLog.sink { entries.append($0) }
        try await arbiter.requestTakeover(session: "a", label: "A")
        _ = try arbiter.leaseID(for: .mcp("a"), method: "PerformAction")
        _ = try? arbiter.leaseID(for: .mcp("b"), method: "PerformAction")
        #expect(entries.map(\.method) == ["PerformAction"])
        #expect(entries.first?.session == "a")
        subscription.cancel()
    }
}
