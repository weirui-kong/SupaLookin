//
//  SPLKBridge+Geometry.swift
//  SPLKModelBridge
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SHARED

import Foundation
import CoreGraphics
import SPLKProtocol
import SPLKServer
#if canImport(UIKit)
import UIKit
public typealias SPLKBridgeColor = UIColor
public typealias SPLKBridgeImage = UIImage
#else
import AppKit
public typealias SPLKBridgeColor = NSColor
public typealias SPLKBridgeImage = NSImage
#endif

public enum SPLKBridge {}

extension SPLKBridge {

    // MARK: - Geometry

    static func point(_ point: CGPoint) -> SPLKV2Point {
        var message = SPLKV2Point()
        message.x = Double(point.x)
        message.y = Double(point.y)
        return message
    }

    static func size(_ size: CGSize) -> SPLKV2Size {
        var message = SPLKV2Size()
        message.width = Double(size.width)
        message.height = Double(size.height)
        return message
    }

    static func rect(_ rect: CGRect) -> SPLKV2Rect {
        var message = SPLKV2Rect()
        message.origin = point(rect.origin)
        message.size = size(rect.size)
        return message
    }

    static func cgPoint(_ message: SPLKV2Point) -> CGPoint {
        CGPoint(x: message.x, y: message.y)
    }

    static func cgSize(_ message: SPLKV2Size) -> CGSize {
        CGSize(width: message.width, height: message.height)
    }

    static func cgRect(_ message: SPLKV2Rect) -> CGRect {
        CGRect(origin: cgPoint(message.origin), size: cgSize(message.size))
    }

    static func insets(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) -> SPLKV2Insets {
        var message = SPLKV2Insets()
        message.top = Double(top)
        message.left = Double(left)
        message.bottom = Double(bottom)
        message.right = Double(right)
        return message
    }

    // MARK: - NSValue

    // Each side builds NSValues the way its own Objective-C code reads them.
    static func pointValue(_ value: Any?) -> CGPoint? {
        guard let value = value as? NSValue else { return nil }
        #if canImport(UIKit)
        return value.cgPointValue
        #else
        return value.pointValue
        #endif
    }

    static func makeValue(point: CGPoint) -> NSValue {
        #if canImport(UIKit)
        return NSValue(cgPoint: point)
        #else
        return NSValue(point: point)
        #endif
    }

    static func sizeValue(_ value: Any?) -> CGSize? {
        guard let value = value as? NSValue else { return nil }
        #if canImport(UIKit)
        return value.cgSizeValue
        #else
        return value.sizeValue
        #endif
    }

    static func makeValue(size: CGSize) -> NSValue {
        #if canImport(UIKit)
        return NSValue(cgSize: size)
        #else
        return NSValue(size: size)
        #endif
    }

    static func rectValue(_ value: Any?) -> CGRect? {
        guard let value = value as? NSValue else { return nil }
        #if canImport(UIKit)
        return value.cgRectValue
        #else
        return value.rectValue
        #endif
    }

    static func makeValue(rect: CGRect) -> NSValue {
        #if canImport(UIKit)
        return NSValue(cgRect: rect)
        #else
        return NSValue(rect: rect)
        #endif
    }

    static func insetsMessage(_ value: Any?) -> SPLKV2Insets? {
        guard let value = value as? NSValue else { return nil }
        #if canImport(UIKit)
        let insets = value.uiEdgeInsetsValue
        #else
        let insets = value.edgeInsetsValue
        #endif
        return self.insets(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
    }

    static func makeValue(insets message: SPLKV2Insets) -> NSValue {
        #if canImport(UIKit)
        return NSValue(uiEdgeInsets: UIEdgeInsets(top: message.top, left: message.left, bottom: message.bottom, right: message.right))
        #else
        return NSValue(edgeInsets: NSEdgeInsets(top: message.top, left: message.left, bottom: message.bottom, right: message.right))
        #endif
    }

    // CGVector, UIOffset and CGAffineTransform share their layout on both platforms, but only UIKit has NSValue accessors for them.
    static func structValue<T>(_ value: Any?, as type: T.Type, encoding: String) -> T? {
        guard let value = value as? NSValue, String(cString: value.objCType) == encoding else { return nil }
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        value.getValue(pointer, size: MemoryLayout<T>.size)
        return pointer.pointee
    }

    static func makeStructValue<T>(_ value: T, encoding: String) -> NSValue {
        withUnsafeBytes(of: value) { bytes in
            encoding.withCString { NSValue(bytes: bytes.baseAddress!, objCType: $0) }
        }
    }

    struct Vector2 {
        var first: CGFloat
        var second: CGFloat
    }

    static let vectorEncoding = "{CGVector=dd}"
    static let offsetEncoding = "{UIOffset=dd}"
    static let transformEncoding = "{CGAffineTransform=dddddd}"

    // MARK: - Color

    static func color(_ color: SPLKBridgeColor) -> SPLKV2Color? {
        guard let components = rgbaComponents(of: color) else { return nil }
        return self.color(rgba: components)
    }

    static func color(rgba components: [Any]) -> SPLKV2Color? {
        let numbers = components.compactMap { ($0 as? NSNumber)?.floatValue }
        guard numbers.count == 4 else { return nil }
        var message = SPLKV2Color()
        message.r = numbers[0]
        message.g = numbers[1]
        message.b = numbers[2]
        message.a = numbers[3]
        return message
    }

    static func rgbaArray(_ message: SPLKV2Color) -> [NSNumber] {
        [message.r, message.g, message.b, message.a].map { NSNumber(value: Double($0)) }
    }

    static func makeColor(_ message: SPLKV2Color) -> SPLKBridgeColor {
        SPLKBridgeColor(red: CGFloat(message.r), green: CGFloat(message.g), blue: CGFloat(message.b), alpha: CGFloat(message.a))
    }

    // The same reading each side's v1 `splk_rgbaComponents` did.
    static func rgbaComponents(of color: SPLKBridgeColor) -> [NSNumber]? {
        #if canImport(UIKit)
        let cgColor = color.cgColor
        guard let components = cgColor.components else { return nil }
        let values: [CGFloat]
        switch cgColor.numberOfComponents {
        case 4: values = components
        case 2: values = [components[0], components[0], components[0], components[1]]
        case 1: values = [components[0], components[0], components[0], components[0]]
        default: return nil
        }
        return values.map { NSNumber(value: Double($0)) }
        #else
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { NSNumber(value: Double($0)) }
        #endif
    }

    // MARK: - Image

    static func encodedImage(_ image: SPLKBridgeImage?) -> SPLKV2EncodedImage? {
        guard let image, let data = pngData(of: image) else { return nil }
        var message = SPLKV2EncodedImage()
        message.format = .png
        message.data = data
        #if canImport(UIKit)
        message.scale = Double(image.scale)
        #else
        message.scale = 1
        #endif
        return message
    }

    public static func encodedImage(data: Data?) -> SPLKV2EncodedImage? {
        guard let data else { return nil }
        var message = SPLKV2EncodedImage()
        message.format = .png
        message.data = data
        return message
    }

    static func makeImage(_ message: SPLKV2EncodedImage) -> SPLKBridgeImage? {
        #if canImport(UIKit)
        return UIImage(data: message.data, scale: message.scale > 0 ? CGFloat(message.scale) : 1)
        #else
        return NSImage(data: message.data)
        #endif
    }

    private static func pngData(of image: SPLKBridgeImage) -> Data? {
        #if canImport(UIKit)
        return image.pngData()
        #else
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }
}

#endif
