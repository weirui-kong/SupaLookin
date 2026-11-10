//
//  SPLKVideoSourceTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Testing
import SPLKProtocol
@testable import SupaLookin

struct SPLKVideoSourceTests {

    private func screen(_ width: Double, _ height: Double, scale: Double = 3, _ orientation: SPLKV2ScreenInfo.Orientation) -> SPLKV2ScreenInfo {
        var screen = SPLKV2ScreenInfo()
        screen.size.width = width
        screen.size.height = height
        screen.scale = scale
        screen.orientation = orientation
        return screen
    }

    @Test func framesTurnToTheInterfaceOrientation() {
        #expect(SPLKVideoSource.rotation(frameWidth: 1179, frameHeight: 2556, screen: screen(393, 852, .portrait)) == .none)
        #expect(SPLKVideoSource.rotation(frameWidth: 1179, frameHeight: 2556, screen: screen(852, 393, .landscapeLeft)) == .clockwise)
        #expect(SPLKVideoSource.rotation(frameWidth: 1179, frameHeight: 2556, screen: screen(852, 393, .landscapeRight)) == .counterclockwise)
        // A capture that already follows the interface orientation stays as it is.
        #expect(SPLKVideoSource.rotation(frameWidth: 2556, frameHeight: 1179, screen: screen(852, 393, .landscapeLeft)) == .none)
        #expect(SPLKVideoSource.rotation(frameWidth: 1179, frameHeight: 2556, screen: SPLKV2ScreenInfo()) == .none)
    }

    // Recorded from the iPhone Duo simulator, which has two panels.
    private let duoScreens = [
        SPLKSimulatorScreen(screenID: 5, screenType: 4, pixelSize: CGSize(width: 7680, height: 4320)),
        SPLKSimulatorScreen(screenID: 3, screenType: 0, pixelSize: CGSize(width: 2007, height: 2853)),
        SPLKSimulatorScreen(screenID: 1, screenType: 0, pixelSize: CGSize(width: 1398, height: 2034)),
    ]

    @Test func displayMatchesTheAppsScreen() {
        #expect(SPLKSimulatorScreen.choose(duoScreens, pixelSize: CGSize(width: 1398, height: 2034))?.screenID == 1)
        #expect(SPLKSimulatorScreen.choose(duoScreens, pixelSize: CGSize(width: 2853, height: 2007))?.screenID == 3)
        #expect(SPLKSimulatorScreen.choose(duoScreens, pixelSize: CGSize(width: 669, height: 951) .applying(.init(scaleX: 3, y: 3)))?.screenID == 3)
    }

    @Test func displayFallsBackToTheMainPanel() {
        #expect(SPLKSimulatorScreen.choose(duoScreens, pixelSize: CGSize(width: 100, height: 100))?.screenID == 1)
        #expect(SPLKSimulatorScreen.choose(duoScreens, pixelSize: .zero)?.screenID == 1)
        #expect(SPLKSimulatorScreen.choose([], pixelSize: .zero) == nil)
    }

    @Test func serialNumbersMatchCaptureDevices() {
        #expect(SPLKDeviceVideoSource.matches(uniqueID: "00008110001A2B3C4D5E801E", serialNumber: "00008110-001A2B3C4D5E801E"))
        #expect(SPLKDeviceVideoSource.matches(uniqueID: "00008110-001a2b3c4d5e801e", serialNumber: "00008110001A2B3C4D5E801E"))
        #expect(SPLKDeviceVideoSource.matches(uniqueID: "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678", serialNumber: "A1B2C3D4E5F60718293A4B5C6D7E8F9012345678"))
        #expect(!SPLKDeviceVideoSource.matches(uniqueID: "00008110001A2B3C4D5E801E", serialNumber: "00008110-001A2B3C4D5E801F"))
        #expect(!SPLKDeviceVideoSource.matches(uniqueID: "", serialNumber: ""))
    }

    @Test func getScreenIsReadOnly() {
        let tool = SPLKMCPTools.tools.first { $0.name == "get_screen" }
        #expect(tool?.annotations.readOnlyHint == true)
    }
}
