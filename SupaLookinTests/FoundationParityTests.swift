//
//  FoundationParityTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import Testing
import LookinShared
@testable import SupaLookin

// Expected values were produced by running the Objective-C sources in LookinClient/.
struct FoundationParityTests {

    @Test(arguments: [
        ("1.2.8", "1.2.7", false),
        ("1.2.7", "1.2.7", true),
        ("1.10.0", "1.9.0", false),
        ("1.9.0", "1.10.0", true),
        ("2.0.0", "1.9.9", false),
        ("1.2.3", "1.2.10", true),
    ])
    func versionComparer(expected: String, real: String, result: Bool) {
        #expect(LKVersionComparer.compare(withNewest: expected, user: real) == result)
        #expect(LKVersionComparer.compare(withExpectedVersion: expected, realVersion: real) == result)
    }

    @Test(arguments: [
        ("lay", "layoutsubviews", 0.2589743590),
        ("abc", "axbxc", 0.4966666667),
        ("hello", "hello world", 0.3172727273),
        ("setneedslayout", "setneedsdisplay", 0.3617460317),
        ("xyz", "layoutsubviews", 0.0404761905),
        ("frm", "frame", 0.4966666667),
    ])
    func fuzzyScore(input: String, candidate: String, expected: Double) {
        #expect(abs(Double(input.score(against: candidate)) - 0) < 1e-9)
        #expect(abs(Double(input.score(against: candidate, fuzziness: 0.5, options: .none)) - expected) < 1e-9)
    }

    @Test(arguments: [
        ("lay", ["layoutSubviews", "setNeedsLayout", "layoutIfNeeded"]),
        ("SetNeeds", ["setNeedsLayout", "setNeedsDisplay", "sizeToFit"]),
        ("vew", ["subviews", "layoutSubviews", "superview"]),
        ("desc", ["description", "debugDescription", "removeFromSuperview"]),
        ("zzz", ["sizeToFit", "subviews", "superview"]),
    ])
    func bestMatches(input: String, expected: [String]) {
        let candidates = ["layoutSubviews", "setNeedsLayout", "layoutIfNeeded", "removeFromSuperview", "sizeToFit", "setNeedsDisplay", "description", "debugDescription", "superview", "subviews"]
        #expect(LKHelper.bestMatches(in: candidates, input: input, maxResultsCount: 3) == expected)
    }

    @Test(arguments: [
        (0.5, 0.25, 1.0, 1.0, "(128, 64, 255)", "#7f3fff"),
        (1.0, 0.0, 0.0, 0.5, "(255, 0, 0, 0.50)", "#ff00007f"),
        (0.1, 0.2, 0.3, 0.4, "(26, 51, 76, 0.40)", "#19334c66"),
        (0.0, 0.0, 0.0, 0.0, "(0, 0, 0, 0.00)", "#00000000"),
        (0.999, 0.004, 0.5, 0.999, "(255, 1, 128, 1.00)", "#fe017ffe"),
    ])
    func colorStrings(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat, rgba: String, hex: String) {
        let color = NSColor(red: red, green: green, blue: blue, alpha: alpha)
        #expect(color.rgbaString == rgba)
        #expect(color.hexString == hex)
    }

    @Test func colorComponentsRoundTrip() throws {
        let color = NSColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        let restored = try #require(NSColor.color(fromRGBAComponents: color.rgbaComponents()))
        #expect(restored.hexString == color.hexString)
        #expect(NSColor.color(fromRGBAComponents: nil) == nil)
    }

    @Test func preferenceDefaultsAreWrittenOnFirstLaunch() throws {
        let suiteName = "SupaLookinNextTests.preferences.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let manager = LKPreferenceManager(userDefaults: userDefaults)

        #expect(manager.showOutline.currentBOOLValue == true)
        #expect(manager.showHiddenItems.currentBOOLValue == false)
        #expect(manager.doubleClickBehavior == .collapse)
        #expect(manager.rgbaFormat == true)
        #expect(manager.zInterspace.currentDoubleValue == 0.22)
        #expect(manager.appearanceType == .system)
        #expect(manager.expansionIndex == 3)
        #expect(manager.imageContrastLevel == 0)
        #expect(manager.syncConsoleTarget == true)
        #expect(manager.freeRotation.currentBOOLValue == true)
        #expect(manager.fastMode.currentBOOLValue == false)
        #expect(manager.collapsedAttrGroups == [LookinAttrGroup_Class])
        #expect(manager.preferredExportCompression == 0.5)
        #expect(manager.previewDimension.currentIntegerValue == LookinPreviewDimension.dimension3D.rawValue)
        #expect(manager.previewScale.currentDoubleValue == Double(LKInitialPreviewScale))
        #expect(manager.measureState.currentIntegerValue == LookinMeasureState.no.rawValue)

        // The same keys and values Lookin writes when they are missing
        #expect(userDefaults.object(forKey: "showOutline") as? Bool == true)
        #expect(userDefaults.object(forKey: "showHiddenItems") as? Bool == false)
        #expect(userDefaults.object(forKey: "doubleClickBehavior") as? Int == 0)
        #expect(userDefaults.object(forKey: "egbaFormat") as? Bool == true)
        #expect(userDefaults.object(forKey: "zInterspace_v095") as? Double == 0.22)
        #expect(userDefaults.object(forKey: "appearanceType") as? Int == 2)
        #expect(userDefaults.object(forKey: "expansionIndex") as? Int == 3)
        #expect(userDefaults.object(forKey: "contrastLevel") as? Int == 0)
        #expect(userDefaults.object(forKey: "syncConsoleTarget") as? Bool == true)
        #expect(userDefaults.object(forKey: "FreeRotation") as? Bool == true)
        #expect(userDefaults.object(forKey: "fastMode") as? Bool == false)
        #expect(userDefaults.object(forKey: "preferredExportCompression") as? Double == 0.5)
        #expect(userDefaults.integer(forKey: "preVer") == Int(LOOKIN_CLIENT_VERSION))
    }

    @Test func preferenceValuesRoundTrip() throws {
        let suiteName = "SupaLookinNextTests.preferences.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let manager = LKPreferenceManager(userDefaults: userDefaults)
        manager.shouldStoreToLocal = true
        manager.rgbaFormat = false
        manager.appearanceType = .dark
        manager.zInterspace.setDoubleValue(0.4, ignoreSubscriber: nil)

        let reloaded = LKPreferenceManager(userDefaults: userDefaults)
        #expect(reloaded.rgbaFormat == false)
        #expect(reloaded.appearanceType == .dark)
        #expect(reloaded.zInterspace.currentDoubleValue == 0.4)
    }

    @Test func pixelSnapping() {
        let scale = NSScreen.main?.backingScaleFactor ?? 1
        #expect(CGFloat(1.3).snappedToPixel == ceil(1.3 * scale) / scale)
        #expect(CGFloat(2).snappedToPixel == 2)
        #expect(CGFloat.greatestFiniteMagnitude.snappedToPixel == .greatestFiniteMagnitude)
    }

    @Test func alignBottomRespectsFlippedSuperview() {
        let flipped = LKBaseView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let flippedChild = NSView()
        flipped.addSubview(flippedChild)
        flippedChild.setHeight(20).alignBottom(10)
        #expect(flippedChild.frame.minY == 70)

        let unflipped = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let unflippedChild = NSView()
        unflipped.addSubview(unflippedChild)
        unflippedChild.setHeight(20).alignBottom(10)
        #expect(unflippedChild.frame.minY == 10)
    }

    @Test func kvoSubjectEmitsCurrentValueThenEachNotify() {
        var value = 1
        let subject = LKKVOSubject { value }
        var received: [Int] = []
        let cancellable = subject.publisher.sink { received.append($0) }
        value = 2
        subject.notify()
        value = 3
        subject.notify()
        cancellable.cancel()
        #expect(received == [1, 2, 3])
    }
}
