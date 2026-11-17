//
//  SPLKModesLiveTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Cocoa
import Testing
import SPLKProtocol
import SPLKServer
@testable import SupaLookin

// Drives the real window against the e2e demo on a booted simulator. Run with TEST_RUNNER_SPLK_VIDEO_E2E=1, apart from SPLKVideoLiveTests: the demo serves one session at a time.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SPLK_VIDEO_E2E"] == "1"))
struct SPLKModesLiveTests {

    private func wait(_ what: String, timeout: TimeInterval = 10, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                Issue.record("timed out waiting for \(what)")
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func counter(_ name: String, session: SPLKDeviceSession, controllerOid: UInt) async throws -> Int {
        let result = try await session.invoke(oid: controllerOid, text: name)
        return Int(result?["description"] as? String ?? "") ?? -1
    }

    // Clicks the video where the item's center is on the phone.
    private func click(_ item: SPLKDisplayItem, screen: CGSize, in videoView: SPLKVideoView) {
        let frame = item.calculateFrameToRoot()
        let rect = videoView.videoRect
        clickVideo(at: CGPoint(x: rect.minX + frame.midX / screen.width * rect.width, y: rect.maxY - frame.midY / screen.height * rect.height), in: videoView)
    }

    private func clickVideo(at point: CGPoint, in videoView: SPLKVideoView) {
        let location = videoView.convert(point, to: nil)
        let windowNumber = videoView.window?.windowNumber ?? 0
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            if type == .leftMouseDown {
                videoView.mouseDown(with: event)
            } else {
                videoView.mouseUp(with: event)
            }
        }
    }

    @Test func modesSwitchAndLiveControlReachesTheApp() async throws {
        // The test host's own launch discovery would replace sessions opened before it finishes.
        try await Task.sleep(for: .seconds(3))
        let apps = await SPLKAppsManager.sharedInstance.fetchAppInfos(withImage: false, localInfos: nil)
        let app = try #require(apps.first { $0.appInfo?.appBundleIdentifier == "icu.retrouvailles.splkdemo" })
        let info = try #require(try await app.fetchHierarchyData())
        let session = try #require(app.session)

        SPLKNavigationManager.sharedInstance.showStaticWorkspace()
        let windowController = try #require(SPLKNavigationManager.sharedInstance.staticWindowController)
        let viewController = windowController.viewController
        let transition = viewController.modeTransition
        let dataSource = SPLKStaticHierarchyDataSource.sharedInstance
        let manager = SPLKPreferenceManager.mainManager
        SPLKAppsManager.sharedInstance.inspectingApp = app
        dataSource.reload(with: info, keepState: false)
        try await Task.sleep(for: .seconds(1))

        // Flat, the projected screen has the phone's aspect and lies inside the preview.
        manager.previewDimension.setIntegerValue(SPLKPreviewDimension.dimension2D.rawValue, ignoreSubscriber: nil)
        try await Task.sleep(for: .seconds(0.5))
        let preview = try #require(viewController.viewsPreviewController)
        let screenRect = try #require(preview.screenRect(in: viewController.transitionOverlay))
        let appScreen = CGSize(width: info.appInfo?.screenWidth ?? 1, height: info.appInfo?.screenHeight ?? 1)
        #expect(abs(screenRect.width / screenRect.height - appScreen.width / appScreen.height) < 0.02)
        #expect(viewController.transitionOverlay.bounds.contains(screenRect))
        if let path = ProcessInfo.processInfo.environment["SPLK_VIDEO_OUT"], let snapshot = preview.screenSnapshot() {
            try NSBitmapImageRep(cgImage: snapshot).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }

        manager.previewDimension.setIntegerValue(SPLKPreviewDimension.dimension3D.rawValue, ignoreSubscriber: nil)
        dataSource.adjustExpansion(byIndex: 2, referenceDict: nil)
        let expandedBefore = dataSource.flatItems.filter(\.isExpanded).count
        #expect(expandedBefore > 1)
        let screen = CGSize(width: info.appInfo?.screenWidth ?? 0, height: info.appInfo?.screenHeight ?? 0)
        let button = try #require(dataSource.flatItems.first { $0.viewObject?.classChainList?.first == "UIButton" })
        let controllerOid = try #require(dataSource.flatItems.first { $0.hostViewControllerObject?.classChainList?.first == "SPLKDemo.SPLKDemoViewController" }?.hostViewControllerObject?.oid)

        // Inspect → Live Control
        try await session.arbiter.startLiveControl()
        try await wait("Live Control") { transition.displayedMode == .liveControl && !transition.isTransitioning }
        #expect(!viewController.arePanelsVisible)
        #expect(viewController.liveController.view.superview != nil)
        #expect(dataSource.flatItems.allSatisfy { !$0.isExpanded })
        #expect(manager.previewDimension.currentIntegerValue == SPLKPreviewDimension.dimension2D.rawValue)
        let videoView = viewController.liveController.videoView
        try await wait("a video frame") { videoView.hasFrame }
        #expect(videoView.isInputEnabled)
        let reload = windowController.window?.toolbar?.items.first { $0.itemIdentifier == SPLKToolBarIdentifier_Reload }
        #expect(reload?.isEnabled == false)
        #expect(windowController.supportedAppMenuActions == [.inspectMode, .liveControlMode, .shake, .home, .lock])

        // A click on the video taps the demo's button.
        let tapsBefore = try await counter("buttonTaps", session: session, controllerOid: controllerOid)
        click(button, screen: screen, in: videoView)
        try await Task.sleep(for: .seconds(1))
        #expect(try await counter("buttonTaps", session: session, controllerOid: controllerOid) == tapsBefore + 1)

        // On a simulator the click goes through dtuhidd, so the software keyboard's keys can be clicked too.
        if await session.refreshInputAvailability() == .host, screen == CGSize(width: 466, height: 678) {
            let textView = try #require(dataSource.flatItems.first { $0.viewObject?.classChainList?.first == "UITextView" })
            click(textView, screen: screen, in: videoView)
            try await Task.sleep(for: .seconds(1.5))
            let before = try await session.invoke(oid: UInt(textView.viewObject!.oid), text: "text")?["description"] as? String ?? ""
            // The "m" key of the iPhone Duo simulator's keyboard, as measured on its screen.
            let rect = videoView.videoRect
            let point = CGPoint(x: rect.minX + 0.7954 * rect.width, y: rect.maxY - 0.8358 * rect.height)
            clickVideo(at: point, in: videoView)
            try await Task.sleep(for: .seconds(1))
            let after = try await session.invoke(oid: UInt(textView.viewObject!.oid), text: "text")?["description"] as? String ?? ""
            // Focusing can select a word, which the key then replaces, so only the typed letter is certain.
            #expect(after != before && after.hasSuffix("m"))
        }

        let shakesBefore = try await counter("shakes", session: session, controllerOid: controllerOid)
        windowController.appMenuManagerDidSelectModeAction(.shake)
        try await Task.sleep(for: .seconds(1))
        #expect(try await counter("shakes", session: session, controllerOid: controllerOid) == shakesBefore + 1)

        // An agent takes over from Live Control: the video stays, input stops.
        try await session.arbiter.requestTakeover(session: "live-test", label: "Test Agent")
        try await wait("Takeover") { transition.displayedMode == .takeover(label: "Test Agent") && !transition.isTransitioning }
        #expect(!videoView.isInputEnabled)
        #expect(windowController.supportedAppMenuActions == [.endTakeover])

        // End Takeover returns to Inspect, reloading and restoring the hierarchy.
        windowController.appMenuManagerDidSelectModeAction(.endTakeover)
        try await wait("Inspect", timeout: 15) { transition.displayedMode == .inspect && !transition.isTransitioning }
        #expect(session.arbiter.mode == .inspect)
        #expect(viewController.arePanelsVisible)
        #expect(viewController.liveController.view.superview == nil)
        #expect(manager.previewDimension.currentIntegerValue == SPLKPreviewDimension.dimension3D.rawValue)
        #expect(dataSource.flatItems.filter(\.isExpanded).count == expandedBefore)
        #expect(reload?.isEnabled == true)
        #expect(throws: (any Error).self) {
            try session.arbiter.renewTakeover(session: "live-test")
        }

        // An agent taking over from Inspect switches the window by itself.
        try await session.arbiter.requestTakeover(session: "live-test", label: "Test Agent")
        try await wait("Takeover from Inspect") { transition.displayedMode == .takeover(label: "Test Agent") && !transition.isTransitioning }
        #expect(!viewController.arePanelsVisible)
        await session.arbiter.releaseTakeover(session: "live-test")
        try await wait("Inspect after release", timeout: 15) { transition.displayedMode == .inspect && !transition.isTransitioning }
        #expect(viewController.arePanelsVisible)
    }
}
