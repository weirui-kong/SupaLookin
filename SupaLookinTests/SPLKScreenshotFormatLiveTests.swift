//
//  SPLKScreenshotFormatLiveTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/25.
//

import Cocoa
import Testing
import SPLKModelBridge
import SPLKProtocol
import SPLKServer
@testable import SupaLookin

// 20261125-screenshot-qoi.md. Runs against SPLK Chat on one connected device or simulator. Run with TEST_RUNNER_SPLK_SCREENSHOT_LIVE=1.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SPLK_SCREENSHOT_LIVE"] == "1"))
@MainActor
struct SPLKScreenshotFormatLiveTests {

    private static let maxItems = 80

    private func groupScreenshots(of items: [SPLKDisplayItem], session: SPLKDeviceSession) async throws -> [UInt64: SPLKV2EncodedImage] {
        let package = SPLKStaticAsyncUpdateTasksPackage()
        package.tasks = items.map { item in
            let task = SPLKStaticAsyncUpdateTask()
            task.oid = item.layerObject?.oid ?? 0
            task.taskType = .groupScreenshot
            task.frameSize = item.frame.size
            return task
        }
        var images: [UInt64: SPLKV2EncodedImage] = [:]
        for try await streamItem in try await session.details([package]) {
            if case .nodeDetail(let message) = streamItem.item, message.hasGroupScreenshot {
                images[message.oid] = message.groupScreenshot
            }
        }
        return images
    }

    private func image(_ message: SPLKV2EncodedImage) -> NSImage? {
        var detail = SPLKV2NodeDetail()
        detail.groupScreenshot = message
        return SPLKBridge.detail(detail).groupScreenshot
    }

    private func maxDifference(_ a: [UInt8], _ b: [UInt8]) -> Int {
        var result = 0
        for index in a.indices {
            result = max(result, abs(Int(a[index]) - Int(b[index])))
        }
        return result
    }

    private func pixels(_ image: NSImage) -> (width: Int, height: Int, bytes: [UInt8])? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (width, height, bytes)
    }

    @Test func qoiMatchesPNG() async throws {
        // The test host's own launch discovery would replace sessions opened before it finishes.
        try await Task.sleep(for: .seconds(3))
        let apps = await SPLKAppsManager.sharedInstance.fetchAppInfos(withImage: false, localInfos: nil)
        let chats = apps.filter { $0.appInfo?.appBundleIdentifier == "icu.retrouvailles.splkchat" }
        try #require(chats.count == 1, "found \(chats.count) SPLK Chat apps")
        let app = chats[0]
        print("SPLK Chat on \(app.appInfo?.deviceDescription ?? "?") \(app.appInfo?.osDescription ?? "?")")
        let session = try #require(app.session)
        #expect(session.client.capabilities.contains(SPLKCapability.screenshotQOI))

        let info = try #require(try await app.fetchHierarchyData())
        let items = Array(SPLKDisplayItem.itemsIncludingMasks(in: info.displayItems ?? [])
            .filter { $0.layerObject != nil && $0.frame.width >= 1 && $0.frame.height >= 1 }
            .prefix(Self.maxItems))
        try #require(!items.isEmpty)

        let manager = SPLKPreferenceManager.mainManager
        let preferred = manager.screenshotFormat
        defer { manager.screenshotFormat = preferred }

        func fetch(_ format: SPLKScreenshotFormat) async throws -> [UInt64: SPLKV2EncodedImage] {
            manager.screenshotFormat = format
            let start = ContinuousClock.now
            let images = try await groupScreenshots(of: items, session: session)
            let bytes = images.values.reduce(0) { $0 + $1.data.count }
            print("\(format): \(images.count) screenshots, \(bytes / 1024) KB, \(ContinuousClock.now - start)")
            return images
        }
        let qoi = try await fetch(.qoiLZ4)
        let png = try await fetch(.png)
        #expect(!qoi.isEmpty)
        #expect(qoi.values.allSatisfy { $0.format == .qoiLz4 })
        #expect(png.values.allSatisfy { $0.format == .png })
        #expect(Set(qoi.keys) == Set(png.keys))
        #expect(!session.fellBackToPNG.value)

        for (oid, qoiMessage) in qoi {
            let qoiImage = try #require(image(qoiMessage), "QOI screenshot of \(oid) didn't decode")
            let pngImage = try #require(png[oid].flatMap(image))
            // ImageIO derives the PNG's size from its resolution, which rounds differently in the last bits.
            let sizeDifference = max(abs(qoiImage.size.width - pngImage.size.width), abs(qoiImage.size.height - pngImage.size.height))
            #expect(sizeDifference < 0.001, "QOI \(qoiImage.size) vs PNG \(pngImage.size)")
            let a = try #require(pixels(qoiImage)), b = try #require(pixels(pngImage))
            #expect(a.width == b.width && a.height == b.height)
            // PNG stores unpremultiplied colors, so translucent pixels can round differently.
            let difference = maxDifference(a.bytes, b.bytes)
            #expect(difference <= 2, "screenshot of \(oid) differs by \(difference)")
        }
    }
}
