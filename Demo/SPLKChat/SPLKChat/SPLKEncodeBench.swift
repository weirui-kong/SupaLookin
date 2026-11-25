//
//  SPLKEncodeBench.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/25.
//

import Compression
import ImageIO
import UIKit
import UniformTypeIdentifiers

// CGImage is immutable, and the pixels are never written after the bitmap is made.
nonisolated struct SPLKEncodeBenchBitmap: @unchecked Sendable {
    let image: CGImage
    let pixels: Data
    let scale: CGFloat

    var width: Int { image.width }
    var height: Int { image.height }

    // Redraws into the 8-bit premultiplied BGRA layout of SPLKServer's screenshots,
    // whatever range the source was rendered in.
    init?(_ source: CGImage, scale: CGFloat) {
        let width = source.width, height = source.height
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
              let data = context.data else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { return nil }
        self.image = image
        self.pixels = Data(bytes: data, count: width * height * 4)
        self.scale = scale
    }
}

nonisolated struct SPLKEncodeBenchSample: Sendable {
    let title: String
    let bitmaps: [SPLKEncodeBenchBitmap]
    let isBatch: Bool

    var rawBytes: Int { bitmaps.reduce(0) { $0 + $1.pixels.count } }
}

nonisolated struct SPLKEncodeBenchCodec: Sendable {
    let name: String
    let isLossless: Bool
    // Returns the encoded length, 0 on failure.
    let encode: @Sendable (SPLKEncodeBenchBitmap) -> Int
}

nonisolated struct SPLKEncodeBenchResult: Sendable {
    let codec: String
    let isLossless: Bool
    let bytes: Int
    let milliseconds: Double
    let concurrentMilliseconds: Double?

    var failed: Bool { bytes == 0 }
}

nonisolated enum SPLKEncodeBench {

    static let transferBytesPerSecond = 35.0 * 1024 * 1024

    static func codecs() -> [SPLKEncodeBenchCodec] {
        let writable = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
        var codecs: [SPLKEncodeBenchCodec] = [
            .init(name: "PNG, UIImage.pngData (today)", isLossless: true) { bitmap in
                UIImage(cgImage: bitmap.image, scale: bitmap.scale, orientation: .up).pngData()?.count ?? 0
            },
            .init(name: "PNG, filter None", isLossless: true) { imageIO($0.image, .png, png(filter: IMAGEIO_PNG_FILTER_NONE)) },
            .init(name: "PNG, filter Sub", isLossless: true) { imageIO($0.image, .png, png(filter: IMAGEIO_PNG_FILTER_SUB)) },
            .init(name: "PNG, filter Up", isLossless: true) { imageIO($0.image, .png, png(filter: IMAGEIO_PNG_FILTER_UP)) },
            .init(name: "raw + LZ4", isLossless: true) { raw($0, COMPRESSION_LZ4) },
            .init(name: "raw + LZFSE", isLossless: true) { raw($0, COMPRESSION_LZFSE) },
            .init(name: "raw + ZLIB", isLossless: true) { raw($0, COMPRESSION_ZLIB) },
            .init(name: "raw + LZBITMAP", isLossless: true) { raw($0, COMPRESSION_LZBITMAP) },
        ]
        if #available(iOS 27.0, *) {
            codecs.append(.init(name: "raw + LZMESH", isLossless: true) { raw($0, COMPRESSION_LZMESH) })
        }
        codecs += [
            .init(name: "QOI, C -Os", isLossless: true) { qoi($0, optimized: true, then: nil) },
            .init(name: "QOI, C -O0", isLossless: true) { qoi($0, optimized: false, then: nil) },
            .init(name: "QOI + LZ4, C -Os", isLossless: true) { qoi($0, optimized: true, then: COMPRESSION_LZ4) },
            .init(name: "QOI + LZ4, C -O0", isLossless: true) { qoi($0, optimized: false, then: COMPRESSION_LZ4) },
            .init(name: "JPEG q0.9, no alpha", isLossless: false) { imageIO($0.image, .jpeg, lossy) },
        ]
        if writable.contains(UTType.heic.identifier) {
            codecs.append(.init(name: "HEIC q0.9", isLossless: false) { imageIO($0.image, .heic, lossy) })
        }
        if let avif = UTType("public.avif"), writable.contains(avif.identifier) {
            codecs.append(.init(name: "AVIF q0.9", isLossless: false) { imageIO($0.image, avif, lossy) })
        }
        return codecs
    }

    @concurrent static func measure(_ samples: [SPLKEncodeBenchSample]) async -> [[SPLKEncodeBenchResult]] {
        let codecs = codecs()
        var results: [[SPLKEncodeBenchResult]] = []
        for sample in samples {
            if Task.isCancelled { break }
            results.append(codecs.map { measure(sample, with: $0) })
        }
        return results
    }

    static func measure(_ sample: SPLKEncodeBenchSample, with codec: SPLKEncodeBenchCodec) -> SPLKEncodeBenchResult {
        let bitmaps = sample.bitmaps
        let warmUp = bitmaps.map(codec.encode)
        let bytes = warmUp.contains(0) ? 0 : warmUp.reduce(0, +)
        guard bytes > 0 else {
            return .init(codec: codec.name, isLossless: codec.isLossless, bytes: 0, milliseconds: 0, concurrentMilliseconds: nil)
        }
        let runs = sample.isBatch ? 3 : 7
        let serial = median(runs: runs) {
            for bitmap in bitmaps { _ = codec.encode(bitmap) }
        }
        let concurrent = sample.isBatch ? median(runs: runs) {
            DispatchQueue.concurrentPerform(iterations: bitmaps.count) { _ = codec.encode(bitmaps[$0]) }
        } : nil
        return .init(codec: codec.name, isLossless: codec.isLossless, bytes: bytes, milliseconds: serial, concurrentMilliseconds: concurrent)
    }

    private static func median(runs: Int, _ body: () -> Void) -> Double {
        var times: [Double] = []
        var total = 0.0
        while times.count < runs && total < 3000 {
            let start = DispatchTime.now().uptimeNanoseconds
            body()
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            times.append(elapsed)
            total += elapsed
        }
        return times.sorted()[times.count / 2]
    }

    private static var lossy: [CFString: Any] { [kCGImageDestinationLossyCompressionQuality: 0.9] }

    private static func png(filter: Int32) -> [CFString: Any] {
        [kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGCompressionFilter: filter]]
    }

    private static func imageIO(_ image: CGImage, _ type: UTType, _ properties: [CFString: Any]) -> Int {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return 0 }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data.length : 0
    }

    private static func raw(_ bitmap: SPLKEncodeBenchBitmap, _ algorithm: compression_algorithm) -> Int {
        bitmap.pixels.withUnsafeBytes { compress($0, algorithm) }
    }

    private static func compress(_ source: UnsafeRawBufferPointer, _ algorithm: compression_algorithm) -> Int {
        // Room for input that doesn't compress, which LZ4 then grows slightly.
        let capacity = source.count + source.count / 16 + 4096
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { destination.deallocate() }
        return compression_encode_buffer(destination, capacity, source.bindMemory(to: UInt8.self).baseAddress!, source.count, nil, algorithm)
    }

    private static func qoi(_ bitmap: SPLKEncodeBenchBitmap, optimized: Bool, then algorithm: compression_algorithm?) -> Int {
        // QOI's worst case: a 5-byte RGBA op per pixel, plus the 14-byte header and 8-byte end marker.
        let capacity = bitmap.width * bitmap.height * 5 + 22
        let encoded = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { encoded.deallocate() }
        let width = UInt32(bitmap.width), height = UInt32(bitmap.height)
        let length = bitmap.pixels.withUnsafeBytes { pixels in
            let source = pixels.bindMemory(to: UInt8.self).baseAddress!
            return optimized
                ? splk_qoi_encode_release(source, width, height, encoded)
                : splk_qoi_encode_debug(source, width, height, encoded)
        }
        guard let algorithm else { return length }
        return compress(UnsafeRawBufferPointer(start: encoded, count: length), algorithm)
    }
}
