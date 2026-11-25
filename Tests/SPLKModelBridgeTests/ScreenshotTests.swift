//
//  ScreenshotTests.swift
//  SPLKModelBridgeTests
//
//  Created by Weirui Kong on 2026/11/25.
//

import AppKit
import Testing
import SPLKProtocol
import SPLKServer
@testable import SPLKModelBridge

// 20261125-screenshot-qoi.md
struct ScreenshotTests {

    private static let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

    // A screenshot-like image with flat areas, gradients and translucent pixels, in rows padded past width * 4.
    private static func screenshot(width: Int, height: Int, padding: Int = 0) -> CGImage {
        let bytesPerRow = width * 4 + padding
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let alpha = UInt8(x < width / 2 ? 255 : (x * 7 + y * 3) % 256)
                let i = y * bytesPerRow + x * 4
                let premultiply = { (value: Int) in UInt8(value % 256 * Int(alpha) / 255) }
                bytes[i] = premultiply(y < height / 3 ? 40 : x * 3)
                bytes[i + 1] = premultiply(y < height / 3 ? 120 : y * 5)
                bytes[i + 2] = premultiply(y < height / 3 ? 200 : (x ^ y))
                bytes[i + 3] = alpha
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    private static func pixels(_ image: CGImage) -> [UInt8] {
        let data = image.dataProvider!.data! as Data
        return (0..<image.height).flatMap { y in
            data[(y * image.bytesPerRow)..<(y * image.bytesPerRow + image.width * 4)]
        }
    }

    private static func message(_ image: CGImage) throws -> SPLKV2EncodedImage {
        var message = SPLKV2EncodedImage()
        message.format = .qoiLz4
        message.data = try #require(SPLKBridge.qoiLZ4Data(image))
        message.pixelWidth = UInt32(image.width)
        message.pixelHeight = UInt32(image.height)
        return message
    }

    @Test(arguments: [0, 12])
    func roundTripsByteForByte(padding: Int) throws {
        let image = Self.screenshot(width: 97, height: 61, padding: padding)
        let decoded = try #require(SPLKBridge.qoiLZ4Image(try Self.message(image)))
        #expect(decoded.width == 97 && decoded.height == 61)
        #expect(Self.pixels(decoded) == Self.pixels(image))
    }

    @Test func decodesToTheSameSizeAsPNG() throws {
        let image = NSImage(cgImage: Self.screenshot(width: 90, height: 45), size: NSSize(width: 90, height: 45))
        let png = try #require(SPLKBridge.encodedScreenshot(image, format: .png))
        let qoi = try #require(SPLKBridge.encodedScreenshot(image, format: .qoiLz4))
        #expect(png.format == .png)
        #expect(qoi.format == .qoiLz4)
        let fromPNG = try #require(SPLKBridge.makeImage(png))
        let fromQOI = try #require(SPLKBridge.makeImage(qoi))
        #expect(fromQOI.size == fromPNG.size)
    }

    @Test func detailCarriesTheRequestedFormat() throws {
        let detail = SPLKDisplayItemDetail()
        detail.displayItemOid = 7
        detail.groupScreenshot = NSImage(cgImage: Self.screenshot(width: 40, height: 30), size: NSSize(width: 40, height: 30))
        let message = SPLKBridge.detailMessage(detail, screenshotFormat: .qoiLz4)
        #expect(message.groupScreenshot.format == .qoiLz4)
        #expect(SPLKBridge.detailMessage(detail).groupScreenshot.format == .png)
        let restored = SPLKBridge.detail(message)
        #expect(restored.groupScreenshot?.size == NSSize(width: 40, height: 30))
    }

    @Test func choosesQOIOnlyWhenBothEndsSupportItAndItIsAsked() {
        let both: Set<String> = [SPLKCapability.screenshotQOI]
        #expect(SPLKBridge.screenshotFormat(requested: .qoiLz4, capabilities: both) == .qoiLz4)
        #expect(SPLKBridge.screenshotFormat(requested: .qoiLz4, capabilities: []) == .png)
        #expect(SPLKBridge.screenshotFormat(requested: .png, capabilities: both) == .png)
        // An older Mac never sets the field.
        #expect(SPLKBridge.screenshotFormat(requested: .unspecified, capabilities: both) == .png)
    }

    @Test func rejectsDataThatDoesNotDecode() throws {
        var message = try Self.message(Self.screenshot(width: 20, height: 20))
        message.pixelWidth = 21
        #expect(SPLKBridge.makeImage(message) == nil)

        message.pixelWidth = 20
        message.data = Data((0..<500).map { UInt8($0 % 251) })
        #expect(SPLKBridge.makeImage(message) == nil)

        message.data = Data()
        #expect(SPLKBridge.makeImage(message) == nil)

        var truncated = try Self.message(Self.screenshot(width: 64, height: 64))
        truncated.data = truncated.data.prefix(truncated.data.count / 2)
        #expect(SPLKBridge.makeImage(truncated) == nil)
    }
}
