//
//  LKAttributedStringBuilder.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa

/// Each attribute applies to the whole string built so far, so an image appended afterwards keeps none of them.
struct LKAttributedStringBuilder {

    private let string: NSMutableAttributedString?

    init(_ string: String?) {
        self.string = string.map { NSMutableAttributedString(string: $0) }
    }

    var attributedString: NSAttributedString? {
        string?.copy() as? NSAttributedString
    }

    func textColor(_ color: NSColor) -> Self {
        addAttribute(.foregroundColor, value: color)
    }

    func textColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> Self {
        textColor(NSColor(lookinRed: red, green: green, blue: blue))
    }

    func font(_ font: NSFont) -> Self {
        addAttribute(.font, value: font)
    }

    func font(size: CGFloat) -> Self {
        font(.systemFont(ofSize: size))
    }

    func lineHeight(_ lineHeight: CGFloat) -> Self {
        guard let string, string.length > 0 else {
            return self
        }
        let style = paragraphStyle(of: string)
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        return addAttribute(.paragraphStyle, value: style.copy())
    }

    func addImage(named name: String, baselineOffset: CGFloat, marginLeft: CGFloat, marginRight: CGFloat) -> Self {
        guard let string, let image = NSImage(named: name) else {
            return self
        }
        let imageString = Self.attributedString(with: image, baselineOffset: baselineOffset)
        if marginLeft > 0 {
            imageString.insert(Self.fixedSpace(marginLeft), at: 0)
        }
        if marginRight > 0 {
            imageString.append(Self.fixedSpace(marginRight))
        }
        string.append(imageString)
        return self
    }

    private func addAttribute(_ key: NSAttributedString.Key, value: Any) -> Self {
        if let string, string.length > 0 {
            string.addAttribute(key, value: value, range: NSRange(location: 0, length: string.length))
        }
        return self
    }

    private func paragraphStyle(of string: NSAttributedString) -> NSMutableParagraphStyle {
        var effectiveRange = NSRange()
        let existing = string.attribute(.paragraphStyle, at: 0, longestEffectiveRange: &effectiveRange, in: NSRange(location: 0, length: string.length)) as? NSParagraphStyle
        if let existing, effectiveRange.length == string.length, let copy = existing.mutableCopy() as? NSMutableParagraphStyle {
            return copy
        }
        return NSMutableParagraphStyle()
    }

    private static func attributedString(with image: NSImage, baselineOffset: CGFloat) -> NSMutableAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let string = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
        string.addAttribute(.baselineOffset, value: baselineOffset, range: NSRange(location: 0, length: string.length))
        return string
    }

    private static func fixedSpace(_ width: CGFloat) -> NSAttributedString {
        attributedString(with: NSImage(size: NSSize(width: width, height: 1)), baselineOffset: 0)
    }
}
