//
//  LKDashboardAttributeRelationView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/14.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

private let Key_CachedDemangled = "cachedDemangled"

final class LKDashboardAttributeRelationView: LKDashboardAttributeStringArrayView {

    override func stringList(withAttribute attribute: LookinAttribute?) -> [String] {
        guard let attribute else {
            return []
        }
        if let cache = attribute.lookin_getBindObject(forKey: Key_CachedDemangled) as? [String] {
            return cache
        }
        let result = attribute.value as? [String] ?? []
        let demangled = result.map { demangle($0) }
        attribute.lookin_bindObject(demangled, forKey: Key_CachedDemangled)
        return demangled
    }

    private func demangle(_ rawText: String) -> String {
        let nsText = rawText as NSString
        do {
            // 先看看是不是 (AAA : BBB *)
            let regex = try? NSRegularExpression(pattern: "\\(\\s*(\\w+)\\s*:\\s*(\\w+)\\s*\\*\\s*\\)")
            if let match = regex?.firstMatch(in: rawText, range: NSRange(location: 0, length: nsText.length)) {
                assert(match.numberOfRanges == 3)
                let range1 = match.range(at: 1)
                let range2 = match.range(at: 2)
                let substring1 = nsText.substring(with: range1)
                let substring2 = nsText.substring(with: range2)
                let demangled1 = LKSwiftDemangler.simpleParse(input: substring1)
                let demangled2 = LKSwiftDemangler.simpleParse(input: substring2)

                var newText = nsText.replacingCharacters(in: range1, with: demangled1)
                newText = newText.replacingOccurrences(of: substring2, with: demangled2)
                return newText
            }
        }

        do {
            // 再看看是不是 (AAA *)
            let regex = try? NSRegularExpression(pattern: "\\(\\s*(\\w+)\\s*\\*\\s*\\)")
            if let match = regex?.firstMatch(in: rawText, range: NSRange(location: 0, length: nsText.length)) {
                let range = match.range(at: 1)
                let rawClassName = nsText.substring(with: range)
                let demangledText = LKSwiftDemangler.simpleParse(input: rawClassName)
                return nsText.replacingCharacters(in: range, with: demangledText)
            }
        }

        return rawText
    }
}
