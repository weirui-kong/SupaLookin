//
//  SPLKBridge+Screenshot.swift
//  SPLKModelBridge
//
//  Created by Weirui Kong on 2026/11/25.
//

#if SHOULD_COMPILE_SPLK_SHARED

import Compression
import CoreGraphics
import Foundation
import SPLKImageCodec
import SPLKProtocol
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// Layer screenshots as QOI + LZ4, per 20261125-screenshot-qoi.md.
extension SPLKBridge {

    // SPLKServer never draws a side longer than this (SPLKNodeImageMaxLengthInPx).
    static let maxScreenshotSide = 16384

    // What a layer screenshot travels as, given what the Mac asked for and what both ends support.
    public static func screenshotFormat(requested: SPLKV2EncodedImage.Format, capabilities: Set<String>) -> SPLKV2EncodedImage.Format {
        requested == .qoiLz4 && capabilities.contains(SPLKCapability.screenshotQOI) ? .qoiLz4 : .png
    }

    static func encodedScreenshot(_ image: SPLKBridgeImage?, format: SPLKV2EncodedImage.Format) -> SPLKV2EncodedImage? {
        guard let image else { return nil }
        if format == .qoiLz4, let message = qoiLZ4Message(image) {
            return message
        }
        return encodedImage(image)
    }

    private static func qoiLZ4Message(_ image: SPLKBridgeImage) -> SPLKV2EncodedImage? {
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { return nil }
        let scale = Double(image.scale)
        #else
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let scale = 1.0
        #endif
        guard let data = qoiLZ4Data(cgImage) else { return nil }
        var message = SPLKV2EncodedImage()
        message.format = .qoiLz4
        message.data = data
        message.scale = scale
        message.pixelWidth = UInt32(cgImage.width)
        message.pixelHeight = UInt32(cgImage.height)
        return message
    }

    static func qoiLZ4Data(_ image: CGImage) -> Data? {
        let width = image.width, height = image.height
        guard width > 0, height > 0, width <= maxScreenshotSide, height <= maxScreenshotSide else { return nil }
        return withBGRA(image) { pixels, bytesPerRow in
            let capacity = SPLKQOIMaxEncodedSize(UInt32(width), UInt32(height))
            let qoi = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
            defer { qoi.deallocate() }
            let length = SPLKQOIEncode(pixels, UInt32(width), UInt32(height), bytesPerRow, qoi)
            return compress(UnsafeRawBufferPointer(start: qoi, count: length))
        }
    }

    static func qoiLZ4Image(_ message: SPLKV2EncodedImage) -> CGImage? {
        let width = Int(message.pixelWidth), height = Int(message.pixelHeight)
        guard width > 0, height > 0, width <= maxScreenshotSide, height <= maxScreenshotSide, !message.data.isEmpty else { return nil }
        let capacity = SPLKQOIMaxEncodedSize(UInt32(width), UInt32(height))
        let qoi = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { qoi.deallocate() }
        let length = message.data.withUnsafeBytes { source in
            compression_decode_buffer(qoi, capacity, source.bindMemory(to: UInt8.self).baseAddress!, source.count, nil, COMPRESSION_LZ4)
        }
        guard length > 0 else { return nil }
        var pixels = Data(count: width * height * 4)
        let decoded = pixels.withUnsafeMutableBytes { bgra in
            SPLKQOIDecode(qoi, length, UInt32(width), UInt32(height), bgra.bindMemory(to: UInt8.self).baseAddress!)
        }
        guard decoded, let provider = CGDataProvider(data: pixels as CFData), let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: space, bitmapInfo: bgraBitmapInfo, provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    // Sized in points like the PNG path's images, whose PNGs carry the screen scale as their resolution.
    static func makeQOILZ4Image(_ message: SPLKV2EncodedImage) -> SPLKBridgeImage? {
        guard let cgImage = qoiLZ4Image(message) else { return nil }
        let scale = message.scale > 0 ? CGFloat(message.scale) : 1
        #if canImport(UIKit)
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        #else
        return NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale))
        #endif
    }

    private static let bgraBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

    // Hands over the image's own bytes when they're already 8-bit premultiplied BGRA in sRGB, as SPLKServer's screenshots are,
    // and a redrawn copy otherwise.
    private static func withBGRA<Result>(_ image: CGImage, _ body: (UnsafePointer<UInt8>, Int) -> Result?) -> Result? {
        let spaceName = image.colorSpace?.name
        if image.bitsPerComponent == 8, image.bitsPerPixel == 32, !image.bitmapInfo.contains(.floatComponents),
           image.alphaInfo == .premultipliedFirst, image.byteOrderInfo == .order32Little,
           spaceName == CGColorSpace.sRGB || spaceName == CGColorSpaceCreateDeviceRGB().name,
           let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data),
           CFDataGetLength(data) >= image.bytesPerRow * (image.height - 1) + image.width * 4 {
            return body(bytes, image.bytesPerRow)
        }
        let width = image.width, height = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: space, bitmapInfo: bgraBitmapInfo.rawValue),
              let bytes = context.data else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return body(bytes.assumingMemoryBound(to: UInt8.self), width * 4)
    }

    private static func compress(_ source: UnsafeRawBufferPointer) -> Data? {
        guard let base = source.bindMemory(to: UInt8.self).baseAddress, source.count > 0 else { return nil }
        // Room for input that doesn't compress, which LZ4 grows slightly.
        let capacity = source.count + source.count / 16 + 64
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { destination.deallocate() }
        let length = compression_encode_buffer(destination, capacity, base, source.count, nil, COMPRESSION_LZ4)
        return length > 0 ? Data(bytes: destination, count: length) : nil
    }
}

#endif
