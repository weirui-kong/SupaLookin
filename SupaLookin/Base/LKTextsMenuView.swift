//
//  LKTextsMenuView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/14.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

enum LKTextsMenuViewType {
    /// 左侧文字左对齐，右侧文字右对齐
    case justified
    /// 居中显示
    case center
}

final class LKTextsMenuView: LKBaseView {

    private var leftLabels: [LKLabel] = []
    private var rightLabels: [LKLabel] = []
    private var buttons: [Int: NSButton] = [:]

    private let buttonMarginLeft: CGFloat = 4

    /// 默认为 {0, 3, 0, 5}
    var insets = NSEdgeInsets(top: 0, left: 3, bottom: 0, right: 5)

    var type: LKTextsMenuViewType = .justified {
        didSet {
            updateAlignments()
        }
    }

    var font: NSFont?

    /// 默认为 2
    var verSpace: CGFloat = 2

    /// 默认为 10
    var horSpace: CGFloat = 10

    var texts: [LookinStringTwoTuple] = [] {
        didSet {
            let texts = self.texts
            leftLabels.dequeue(count: texts.count, add: { _ in makeLabel() }, notDequeued: { _, label in
                label.isHidden = true
            }, doNext: { idx, label in
                label.isHidden = false
                label.stringValue = texts[idx].first ?? ""
            })
            rightLabels.dequeue(count: texts.count, add: { _ in makeLabel() }, notDequeued: { _, label in
                label.isHidden = true
            }, doNext: { idx, label in
                label.isHidden = false
                label.stringValue = texts[idx].second ?? ""
            })
            assert(leftLabels.count == rightLabels.count)

            updateColors()
            updateAlignments()
            needsLayout = true
        }
    }

    private func makeLabel() -> LKLabel {
        let label = LKLabel()
        label.isSelectable = true
        label.font = font
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        addSubview(label)
        return label
    }

    override func layout() {
        super.layout()

        let visibleRightLabels = rightLabels.visibleViews
        let visibleLeftLabels = leftLabels.visibleViews

        if type == .center {
            var leftLabelMaxWidth = insets.left
            for (idx, leftLabel) in visibleLeftLabels.enumerated() {
                let prevLeftLabel = idx > 0 ? visibleLeftLabels[idx - 1] : nil
                let y = prevLeftLabel.map { $0.frame.maxY + verSpace } ?? 0
                leftLabel.fitSize().setY(y)
                leftLabelMaxWidth = max(leftLabelMaxWidth, leftLabel.frame.width + insets.left)
            }
            for (idx, leftLabel) in visibleLeftLabels.enumerated() {
                leftLabel.setMaxX(leftLabelMaxWidth)

                let midY = leftLabel.frame.midY

                let rightLabel = visibleRightLabels[idx]
                rightLabel.setX(leftLabelMaxWidth + horSpace).fitSize().setMidY(midY)

                if let button = buttons[idx] {
                    var x = rightLabel.frame.maxX
                    if !rightLabel.stringValue.isEmpty {
                        x += buttonMarginLeft
                    }
                    button.fitSize().setX(x).setMidY(midY + 1)
                }
            }
        } else {
            for (idx, rightLabel) in visibleRightLabels.enumerated() {
                let prevLeftLabel = idx > 0 ? visibleLeftLabels[idx - 1] : nil

                let leftLabel = visibleLeftLabels[idx]
                let y = prevLeftLabel.map { $0.frame.maxY + verSpace } ?? 0
                leftLabel.fitSize().setX(0).setY(y)

                var rightLabelMaxX = frame.width
                if let button = buttons[idx] {
                    button.fitSize().alignRight(0).setMidY(leftLabel.frame.midY)
                    rightLabelMaxX = button.frame.minX - buttonMarginLeft
                }
                rightLabel.setX(leftLabel.frame.maxX + horSpace).extendToMaxX(rightLabelMaxX).fitHeight().setMidY(leftLabel.frame.midY)
            }
        }
    }

    private func updateAlignments() {
        leftLabels.forEach { $0.alignment = type == .justified ? .left : .right }
        rightLabels.forEach { $0.alignment = type == .justified ? .right : .left }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var resultHeight: CGFloat = 0

        var leftMaxWidth: CGFloat = 0
        var rightMaxWidth: CGFloat = 0
        for (idx, label) in leftLabels.visibleViews.enumerated() {
            let size = label.bestSize
            leftMaxWidth = max(leftMaxWidth, size.width)
            resultHeight += size.height
            if idx > 0 {
                resultHeight += verSpace
            }
        }
        for (idx, label) in rightLabels.visibleViews.enumerated() {
            var width = label.bestWidth
            if let button = buttons[idx] {
                width += button.bestWidth
                if !label.stringValue.isEmpty {
                    width += buttonMarginLeft
                }
            }
            rightMaxWidth = max(rightMaxWidth, width)
        }

        // 这里多给个 1 的冗余量，来抵消 ShortCocoa 布局时取整带来的误差
        let resultWidth = leftMaxWidth + rightMaxWidth + horSpace + insets.left + insets.right
        return NSSize(width: resultWidth, height: resultHeight)
    }

    override func updateColors() {
        super.updateColors()
        leftLabels.forEach { $0.textColor = (isDarkMode ? NSColor.lookinGray9 : NSColor.lookinGray1).withAlphaComponent(0.7) }
        rightLabels.forEach { $0.textColor = isDarkMode ? .lookinWhite : .lookinBlack }
    }

    /// 在某一行的右侧加一个按钮，业务自己负责这个 button 的点击事件之类的
    func addButton(_ button: NSButton, at idx: Int) {
        if buttons[idx] != nil {
            assertionFailure()
            return
        }
        buttons[idx] = button
        addSubview(button)
        needsLayout = true
    }
}
