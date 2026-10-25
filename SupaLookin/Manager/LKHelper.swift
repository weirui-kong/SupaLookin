//
//  LKHelper.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

let HierarchyMinWidth: CGFloat = 200
let MeasureViewWidth: CGFloat = 240
let DashboardViewWidth: CGFloat = 260
let DashboardHorInset: CGFloat = 10
let DashboardAttrItemHorInterspace: CGFloat = 10
let DashboardAttrItemVerInterspace: CGFloat = 9
let DashboardCardControlCornerRadius: CGFloat = 4
let DashboardSectionMarginTop: CGFloat = 10
let DashboardCardCornerRadius: CGFloat = 6
let DashboardSearchCardInset: CGFloat = 6
let ConsoleInsetLeft: CGFloat = 10
let ConsoleInsetRight: CGFloat = 26
let ZoomSliderMaxValue: CGFloat = 2.8

struct HorizontalMargins {
    var left: CGFloat = 0
    var right: CGFloat = 0
}

extension NSColor {
    static var dashboardCardValueColor: NSColor { NSColor(lookinRed: 223, green: 223, blue: 223) }
    static var dashboardCardControlBackgroundColor: NSColor { NSColor(lookinRed: 40, green: 40, blue: 40) }
    static var dashboardCardControlBorderColor: NSColor { NSColor(lookinRed: 87, green: 87, blue: 87) }
    static var separatorLightModeColor: NSColor { NSColor(lookinRed: 215, green: 215, blue: 215) }
    static var separatorDarkModeColor: NSColor { NSColor(lookinRed: 67, green: 67, blue: 69) }
    static var lookinBlack: NSColor { NSColor(lookinRed: 13, green: 20, blue: 30) }
    static var lookinWhite: NSColor { NSColor(lookinRed: 250, green: 251, blue: 252) }
    static var lookinGray0: NSColor { NSColor(lookinRed: 33, green: 40, blue: 50) }
    static var lookinGray1: NSColor { NSColor(lookinRed: 53, green: 60, blue: 70) }
    static var lookinGray9: NSColor { NSColor(lookinRed: 216, green: 220, blue: 228) }
}

final class LKHelper {

    static let sharedInstance = LKHelper()

    var tempImageFiles: [String] = []

    private init() {}

    static func italicFont(ofSize fontSize: CGFloat) -> NSFont {
        let descriptor = NSFont.systemFont(ofSize: fontSize).fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: fontSize) ?? .systemFont(ofSize: fontSize)
    }

    static var lookinReadableVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    static func openLookinWebsite(withPath path: String) {
        let version = lookinReadableVersion.replacingOccurrences(of: ".", with: "d")
        if let url = URL(string: "https://lookin.work/\(path)?v=\(version)") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openLookinOfficialWebsite() {
        NSWorkspace.shared.open(URL(string: "https://lookin.work")!)
    }

    static func openCustomConfigWebsite() {
        NSWorkspace.shared.open(URL(string: "https://lookin.work/faq/config-file/")!)
    }

    static let isEnglish: Bool = {
        let language = NSLocale.preferredLanguages.first ?? ""
        return !language.hasPrefix("zh")
    }()

    static var accentColor: NSColor {
        .controlAccentColor
    }

    static func bestMatches(in candidates: [String], input: String, maxResultsCount: Int) -> [String] {
        var topResults: [(string: String, score: CGFloat)] = []
        topResults.reserveCapacity(maxResultsCount)
        var lowestScore: CGFloat = 1

        let input = input.lowercased()
        for candidate in candidates {
            if lowestScore >= 1 && topResults.count >= maxResultsCount {
                break
            }

            let lowercasedCandidate = candidate.lowercased()
            let score: CGFloat
            if lowercasedCandidate.contains(input) {
                score = 1
            } else {
                score = input.score(against: lowercasedCandidate, fuzziness: 0.5, options: .none)
            }

            if topResults.count < maxResultsCount {
                topResults.append((candidate, score))
                if score < lowestScore {
                    lowestScore = score
                }
                continue
            }

            if score > lowestScore {
                if let indexToDelete = indexOfSmallestNumber(in: topResults.map(\.score)) {
                    topResults.remove(at: indexToDelete)
                }
                topResults.append((candidate, score))
                lowestScore = smallestNumber(in: topResults.map(\.score))
            }
        }

        return topResults.sorted { $0.score > $1.score }.map(\.string)
    }

    private static func indexOfSmallestNumber(in array: [CGFloat]) -> Int? {
        guard !array.isEmpty else {
            assertionFailure("_indexOfSmallestNumberInArray")
            return nil
        }
        var index: Int?
        var smallestNumber = CGFloat.greatestFiniteMagnitude
        for (idx, number) in array.enumerated() where number < smallestNumber {
            smallestNumber = number
            index = idx
        }
        return index
    }

    private static func smallestNumber(in array: [CGFloat]) -> CGFloat {
        guard !array.isEmpty else {
            assertionFailure("_smallestNumberInArray")
            return 0
        }
        return array.min() ?? .greatestFiniteMagnitude
    }

    static func scrollableTextView() -> NSScrollView {
        NSTextView.scrollableTextView()
    }

    static func validateFrame(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && !isNaN(frame) && !isInf(frame) && !isUnreasonable(frame)
    }

    private static func isNaN(_ rect: CGRect) -> Bool {
        rect.origin.x.isNaN || rect.origin.y.isNaN || rect.size.width.isNaN || rect.size.height.isNaN
    }

    private static func isInf(_ rect: CGRect) -> Bool {
        rect.origin.x.isInfinite || rect.origin.y.isInfinite || rect.size.width.isInfinite || rect.size.height.isInfinite
    }

    private static func isUnreasonable(_ rect: CGRect) -> Bool {
        abs(rect.origin.x) > 100000 || abs(rect.origin.y) > 100000 || rect.size.width < 0 || rect.size.height < 0 || rect.size.width > 100000 || rect.size.height > 100000
    }

    static func alertError(_ error: Error, window: NSWindow?) {
        let error = error as NSError
        guard error.code != LookinErrCode_Discard else {
            return
        }
        guard let window else {
            NSAlert(error: error).runModal()
            return
        }
        NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
    }

    static func alertErrorText(_ title: String, _ detail: String, window: NSWindow?) {
        alertError(LookinError.make(title, detail), window: window)
    }
}
