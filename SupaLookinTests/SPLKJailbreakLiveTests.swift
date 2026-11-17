//
//  SPLKJailbreakLiveTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/18.
//

import Foundation
import Combine
import Testing
import SPLKProtocol
import SPLKServer
@testable import SupaLookin

// Runs against an app with SPLKServer on a jailbroken USB device whose splkhidd is reachable, unlocked. Run with
// TEST_RUNNER_SPLK_JB_SERIAL set to the device's UDID.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SPLK_JB_SERIAL"] != nil))
struct SPLKJailbreakLiveTests {

    private func tabBarControllerOid(_ session: SPLKDeviceSession) async throws -> UInt {
        let info = try #require(try await session.hierarchy())
        let items = SPLKDisplayItem.flatItems(fromHierarchicalItems: info.displayItems ?? []) ?? []
        let controller = items.compactMap(\.hostViewControllerObject).first { $0.classChainList?.contains("UITabBarController") == true }
        return UInt(try #require(controller).oid)
    }

    private func selectedIndex(_ session: SPLKDeviceSession, controller: UInt) async throws -> String {
        try await session.invoke(oid: controller, text: "selectedIndex")?["description"] as? String ?? ""
    }

    private func tap(_ session: SPLKDeviceSession, x: Double, y: Double) async throws -> SPLKDeviceSession.InputBackend {
        var events: [SPLKV2InputEvent] = []
        for phase in [SPLKV2Touch.Phase.began, .ended] {
            var event = SPLKV2InputEvent()
            event.touch.touchID = 1
            event.touch.phase = phase
            event.touch.location.x = x
            event.touch.location.y = y
            events.append(event)
        }
        return try await session.deliverInput(events, screen: session.client.serverHello.app.screen)
    }

    @Test func tapsReachTheDeviceThroughTheHelper() async throws {
        let serial = try #require(ProcessInfo.processInfo.environment["SPLK_JB_SERIAL"])
        // The test host's launch discovery and usbmux's attach notices settle first.
        try await Task.sleep(for: .seconds(3))
        let discoveries = await SPLKConnectionManager.sharedInstance.tryToConnectAllPorts()
        let session = try #require(discoveries.compactMap { discovery -> SPLKDeviceSession? in
            guard case .app(let session) = discovery, session.target == .usbDevice(serialNumber: serial) else { return nil }
            return session
        }.first)
        #expect(session.usbDeviceID != nil)

        #expect(await session.refreshInputAvailability() == .host)
        #expect(SPLKControlHelpViewController.checkResult(.host, isUSBDevice: true, error: session.hostInputError).contains("Helper"))

        // The help panel's "Copy Package to Device".
        let package = try Data(contentsOf: try #require(Bundle.main.url(forResource: SPLKControlHelpViewController.packageName, withExtension: "deb")))
        try await SPLKMobileDeviceAFC.write(package, toDirectory: SPLKControlHelpViewController.packageDirectory, file: "\(SPLKControlHelpViewController.packageName).deb", udid: serial)

        let controller = try await tabBarControllerOid(session)
        let tabCount = 4.0
        // The tab bar sits at the bottom; each tab is a quarter of the width.
        let tabY = 0.955
        #expect(try await tap(session, x: 1.5 / tabCount, y: tabY) == .host)
        try await Task.sleep(for: .seconds(1))
        #expect(try await selectedIndex(session, controller: controller) == "1")
        _ = try await tap(session, x: 0.5 / tabCount, y: tabY)
        try await Task.sleep(for: .seconds(1))
        #expect(try await selectedIndex(session, controller: controller) == "0")
    }

    private func appSession(serial: String, timeout: Duration) async throws -> SPLKDeviceSession {
        let deadline = ContinuousClock.now + timeout
        while true {
            let discoveries = await SPLKConnectionManager.sharedInstance.tryToConnectAllPorts()
            if let session = discoveries.compactMap({ discovery -> SPLKDeviceSession? in
                guard case .app(let session) = discovery, session.target == .usbDevice(serialNumber: serial) else { return nil }
                return session
            }).first {
                return session
            }
            try #require(ContinuousClock.now < deadline, "the app didn't come back")
            try await Task.sleep(for: .seconds(1))
        }
    }

    // What Live Control does first, in a fresh process. The device's first screen capture can make it re-attach over
    // USB, which drops the app (the window then resumes Live Control on the reconnect); a capture after that must keep
    // the app's session.
    @Test func liveControlHoldsAfterTheFirstCapture() async throws {
        let serial = try #require(ProcessInfo.processInfo.environment["SPLK_JB_SERIAL"])
        try await Task.sleep(for: .seconds(3))
        let first = try await appSession(serial: serial, timeout: .seconds(5))
        var session = first
        var ended: [ObjectIdentifier] = []
        let subscription = SPLKConnectionManager.sharedInstance.sessionDidEnd.sink { ended.append(ObjectIdentifier($0)) }
        defer { subscription.cancel() }

        try await session.video.start()
        try await Task.sleep(for: .seconds(8))
        session.video.stop()
        if ended.contains(ObjectIdentifier(session)) {
            print("the first capture dropped the app; reconnecting")
            session = try await appSession(serial: serial, timeout: .seconds(20))
            try await session.video.start()
            try await Task.sleep(for: .seconds(8))
            session.video.stop()
        }
        // Holding the first session keeps its identifier from being reused.
        withExtendedLifetime(first) {}
        #expect(!ended.contains(ObjectIdentifier(session)))
        #expect(await session.refreshInputAvailability() == .host)
    }
}
