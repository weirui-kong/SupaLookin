//
//  SPLKMaskLiveTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/25.
//

import Cocoa
import Testing
import SPLKModelBridge
import SPLKServer
@testable import SupaLookin

// Runs against SPLK Chat launched with `-SPLKChatScreen masks`, on one connected device or simulator. Run with TEST_RUNNER_SPLK_MASK_LIVE=1.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SPLK_MASK_LIVE"] == "1"))
struct SPLKMaskLiveTests {

    private func className(_ item: SPLKDisplayItem) -> String {
        (item.viewObject ?? item.layerObject)?.rawClassName() ?? ""
    }

    private func child(of item: SPLKDisplayItem?, _ name: String) throws -> SPLKDisplayItem {
        try #require(item?.subitems?.first { className($0) == name }, "no \(name) under \(item.map(className) ?? "nil")")
    }

    private func screenshot(of item: SPLKDisplayItem, _ type: SPLKStaticAsyncUpdateTaskType, session: SPLKDeviceSession) async throws -> NSImage? {
        let task = SPLKStaticAsyncUpdateTask()
        task.oid = item.layerObject?.oid ?? 0
        task.taskType = type
        task.frameSize = item.frame.size
        let package = SPLKStaticAsyncUpdateTasksPackage()
        package.tasks = [task]
        for try await streamItem in try await session.details([package]) {
            if case .nodeDetail(let message) = streamItem.item {
                let detail = SPLKBridge.detail(message)
                return type == .soloScreenshot ? detail.soloScreenshot : detail.groupScreenshot
            }
        }
        return nil
    }

    private func hasVisiblePixels(_ image: NSImage?) -> Bool {
        guard let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        let width = 32, height = 32
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return false
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    }

    @Test func masksArriveWithScreenshotsAndFollowTheSwitch() async throws {
        // The test host's own launch discovery would replace sessions opened before it finishes.
        try await Task.sleep(for: .seconds(3))
        let apps = await SPLKAppsManager.sharedInstance.fetchAppInfos(withImage: false, localInfos: nil)
        let chats = apps.filter { $0.appInfo?.appBundleIdentifier == "icu.retrouvailles.splkchat" }
        try #require(chats.count == 1, "found \(chats.count) SPLK Chat apps")
        let app = chats[0]
        print("SPLK Chat on \(app.appInfo?.deviceDescription ?? "?") \(app.appInfo?.osDescription ?? "?"), \(app.appInfo?.screenWidth ?? 0) pt wide")
        let session = try #require(app.session)
        let info = try #require(try await app.fetchHierarchyData())
        let all = SPLKDisplayItem.itemsIncludingMasks(in: info.displayItems ?? [])
        func item(_ name: String) throws -> SPLKDisplayItem {
            try #require(all.first { className($0) == name }, "no \(name)")
        }

        let gradient = try child(of: try item("SPLKChat.SPLKMaskViewCase"), "SPLKChat.SPLKGradientView")
        let shape = try #require(gradient.mask)
        #expect(shape.isMask)
        #expect(className(shape) == "UIView")
        #expect(shape.subitems?.count == 2)
        #expect(!(gradient.subitems ?? []).contains { $0.isMask })
        #expect(hasVisiblePixels(try await screenshot(of: shape, .groupScreenshot, session: session)))

        let imageView = try child(of: try item("SPLKChat.SPLKShapeMaskCase"), "UIImageView")
        let star = try #require(imageView.mask)
        #expect(className(star) == "CAShapeLayer")
        #expect(hasVisiblePixels(try await screenshot(of: star, .groupScreenshot, session: session)))
        #expect(hasVisiblePixels(try await screenshot(of: imageView, .soloScreenshot, session: session)))

        let label = try child(of: try item("SPLKChat.SPLKFadeMaskCase"), "UILabel")
        #expect(label.mask.map(className) == "CAGradientLayer")

        let nested = try child(of: try item("SPLKChat.SPLKNestedMaskCase"), "SPLKChat.SPLKGradientView")
        #expect(nested.mask?.mask.map(className) == "UILabel")
        #expect(nested.mask?.mask?.isMask == true)

        let manager = SPLKPreferenceManager()
        manager.showMaskItems.setBOOLValue(true, ignoreSubscriber: nil)
        let file = SPLKHierarchyFile()
        file.hierarchyInfo = info
        let dataSource = SPLKReadHierarchyDataSource(file: file, preferenceManager: manager)
        #expect(dataSource.flatItems.contains { $0 === shape })
        #expect(shape.isMatched(withSearchString: "mask"))
        manager.showMaskItems.setBOOLValue(false, ignoreSubscriber: nil)
        #expect(!dataSource.flatItems.contains { $0 === shape })

        let controllerOid = try #require(all.first { $0.hostViewControllerObject?.rawClassName() == "SPLKChat.SPLKMasksViewController" }?.hostViewControllerObject?.oid)
        func toggledGradient() async throws -> SPLKDisplayItem {
            let info = try #require(try await app.fetchHierarchyData())
            let all = SPLKDisplayItem.itemsIncludingMasks(in: info.displayItems ?? [])
            return try child(of: all.first { className($0) == "SPLKChat.SPLKToggleMaskCase" }, "SPLKChat.SPLKGradientView")
        }
        #expect(try await toggledGradient().mask != nil)
        _ = try await session.invoke(oid: controllerOid, text: "toggleMask")
        #expect(try await toggledGradient().mask == nil)
        _ = try await session.invoke(oid: controllerOid, text: "toggleMask")
        #expect(try await toggledGradient().mask != nil)
    }
}
