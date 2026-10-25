//
//  NSColor+LookinClient.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/17.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

extension NSColor {

    func rgbaComponents() -> [CGFloat] {
        let rgbColor = usingColorSpace(.sRGB) ?? self
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }

    static func color(fromRGBAComponents components: [Any]?) -> NSColor? {
        guard let components else {
            return nil
        }
        guard components.count == 4 else {
            assertionFailure()
            return nil
        }
        let values = components.map { ($0 as? NSNumber)?.doubleValue ?? 0 }
        return NSColor(red: values[0], green: values[1], blue: values[2], alpha: values[3])
    }

    /// 如果 alpha 为 1 则返回诸如 (15, 17, 19) 这样的格式，如果 alpha 小于 1 则返回诸如 (15, 17, 19, 0.5) 这样的格式
    var rgbaString: String {
        let rgba = rgbaComponents()
        let (r, g, b, a) = (rgba[0], rgba[1], rgba[2], rgba[3])
        if a >= 1 {
            return String(format: "(%.0f, %.0f, %.0f)", r * 255, g * 255, b * 255)
        }
        return String(format: "(%.0f, %.0f, %.0f, %.2f)", r * 255, g * 255, b * 255, a)
    }

    var hexString: String {
        let rgba = rgbaComponents()
        let channels = rgba.map { Int($0 * 255) }
        // 对于色值只有单位数的，在前面补一个0，例如“F”会补齐为“0F”
        let hex = channels.map { channel -> String in
            let string = String(channel, radix: 16)
            return string.count < 2 ? "0" + string : string
        }
        if rgba[3] >= 1 {
            return "#\(hex[0])\(hex[1])\(hex[2])"
        }
        return "#\(hex[0])\(hex[1])\(hex[2])\(hex[3])"
    }
}
