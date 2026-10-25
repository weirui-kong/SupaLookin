//
//  LKMeasureResultView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/10/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

private enum CompareResult {
    case bigger
    case same
    case smaller
}

final class LKMeasureResultView: LKBaseView {

    private let contentView = LKBaseView()

    private let mainImageView = NSImageView()
    private let referImageView = NSImageView()

    private let linesContainerView = LKBaseView()
    private let horSolidLinesLayer = CAShapeLayer()
    private let verSolidLinesLayer = CAShapeLayer()
    private let mainImageViewBorderLayer = CALayer()
    private let referImageViewBorderLayer = CALayer()

    private var textFieldViews: [LKTextFieldView] = []

    private var originalMainFrame = CGRect.zero
    private var originalReferFrame = CGRect.zero

    private var scaledMainFrame = CGRect.zero
    private var scaledReferFrame = CGRect.zero

    private let horInset: CGFloat = 20
    private let verInset: CGFloat = 20
    private let labelHeight: CGFloat = 18

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        hasEffectedBackground = true
        layer?.cornerRadius = DashboardCardCornerRadius

        // label 经常会超出范围
        contentView.layer?.masksToBounds = false
        addSubview(contentView)

        mainImageView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(mainImageView)

        referImageView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(referImageView)

        linesContainerView.layer?.masksToBounds = false
        contentView.addSubview(linesContainerView)

        mainImageViewBorderLayer.borderWidth = 1
        mainImageViewBorderLayer.lookin_removeImplicitAnimations()
        linesContainerView.layer?.addSublayer(mainImageViewBorderLayer)

        referImageViewBorderLayer.borderWidth = 1
        referImageViewBorderLayer.lookin_removeImplicitAnimations()
        linesContainerView.layer?.addSublayer(referImageViewBorderLayer)

        horSolidLinesLayer.lineWidth = 1
        horSolidLinesLayer.lookin_removeImplicitAnimations()
        horSolidLinesLayer.strokeColor = NSColor(lookinRed: 10, green: 127, blue: 251).cgColor
        linesContainerView.layer?.addSublayer(horSolidLinesLayer)

        verSolidLinesLayer.lineWidth = 1
        verSolidLinesLayer.lookin_removeImplicitAnimations()
        verSolidLinesLayer.strokeColor = NSColor(lookinRed: 209, green: 120, blue: 0).cgColor
        linesContainerView.layer?.addSublayer(verSolidLinesLayer)

        updateColors()
    }

    override func updateColors() {
        super.updateColors()
        let borderColor = isDarkMode ? NSColor(lookinRed: 123, green: 123, blue: 123) : NSColor(lookinRed: 190, green: 190, blue: 190)
        referImageViewBorderLayer.borderColor = borderColor.cgColor
        mainImageViewBorderLayer.borderColor = borderColor.cgColor
    }

    override func layout() {
        super.layout()
        mainImageView.frame = scaledMainFrame
        referImageView.frame = scaledReferFrame

        let contentSize = size(fromRectA: scaledMainFrame, rectB: scaledReferFrame)
        contentView.setWidth(contentSize.width).setHeight(contentSize.height).centerInSuperview()

        linesContainerView.frame = contentView.bounds
        horSolidLinesLayer.frame = linesContainerView.bounds
        verSolidLinesLayer.frame = linesContainerView.bounds
        mainImageViewBorderLayer.frame = mainImageView.frame
        referImageViewBorderLayer.frame = referImageView.frame
        renderLinesAndLabels()
    }

    func render(withMainRect originalMainRect: CGRect, mainImage: NSImage?, referRect originalReferRect: CGRect, referImage: NSImage?) {
        originalMainFrame = originalMainRect
        originalReferFrame = originalReferRect

        mainImageView.image = mainImage
        referImageView.image = referImage

        let scaleFactor = calculateScaleFactor(withMainRect: originalMainRect, referRect: originalReferRect)

        // 这里的两个 frame 是稍后真正被 layout 使用的值
        let mainFrame = adjustRect(originalMainRect, withScaleFactor: scaleFactor)
        let referFrame = adjustRect(originalReferRect, withScaleFactor: scaleFactor)

        let minX = min(mainFrame.minX, referFrame.minX)
        let minY = min(mainFrame.minY, referFrame.minY)

        // 下面两句使得两个 rect 作为整体被移动 origin 至 {0, 0}
        scaledMainFrame = mainFrame.offsetBy(dx: -minX, dy: -minY)
        scaledReferFrame = referFrame.offsetBy(dx: -minX, dy: -minY)

        needsLayout = true
    }

    private func renderLinesAndLabels() {
        hideAllLabels()
        horSolidLinesLayer.isHidden = true
        verSolidLinesLayer.isHidden = true

        // 为了方便，mainFrame 记为 A，referRect 记为 B
        let rectA = scaledMainFrame
        let rectB = scaledReferFrame

        // 包裹对方的那个 view 应该被半透明处理，因为此时辅助线基本都落在了被包裹的 view 之外、包裹对方的 view 之内
        if rectA.contains(rectB) {
            // A 包裹 B
            mainImageView.alphaValue = 0.2
            referImageView.alphaValue = 1

        } else if rectB.contains(rectA) {
            // B 包裹 A
            mainImageView.alphaValue = 1
            referImageView.alphaValue = 0.2

        } else if rectA.intersects(rectB) {
            // 两个 view 只有部分是重叠的
            mainImageView.alphaValue = 0.2
            referImageView.alphaValue = 0.2
        } else {
            // 两个 view 没有重叠
            mainImageView.alphaValue = 1
            referImageView.alphaValue = 1
        }

        let minX_A = rectA.minX
        let midX_A = rectA.midX
        let maxX_A = rectA.maxX
        let minX_B = rectB.minX
        let midX_B = rectB.midX
        let maxX_B = rectB.maxX

        let minY_A = rectA.minY
        let midY_A = rectA.midY
        let maxY_A = rectA.maxY
        let minY_B = rectB.minY
        let midY_B = rectB.midY
        let maxY_B = rectB.maxY

        let main = originalMainFrame
        let refer = originalReferFrame

        /** 水平方向的线 START **/
        var horDatas: [LKMeasureResultHorLineData] = []
        func addHor(_ startX: CGFloat, _ endX: CGFloat, _ y: CGFloat, _ value: CGFloat) {
            horDatas.append(LKMeasureResultHorLineData(startX: startX, endX: endX, y: y, displayValue: value))
        }

        switch compare(minX_A, minX_B) {
        case .smaller:
            if compare(maxX_A, minX_B) == .smaller {
                // right to left
                addHor(maxX_A, minX_B, midY_A, refer.minX - main.maxX)
            } else {
                // maxX_A >= minX_B
                switch compare(maxX_A, maxX_B) {
                case .smaller:
                    // right to right
                    addHor(maxX_A, maxX_B, midY_A, refer.maxX - main.maxX)
                case .same:
                    // nothing
                    break
                case .bigger:
                    // right to right
                    addHor(maxX_B, maxX_A, midY_B, main.maxX - refer.maxX)
                    // left to left
                    addHor(minX_A, minX_B, midY_B, refer.minX - main.minX)
                }
            }

        case .same:
            switch compare(maxX_A, maxX_B) {
            case .smaller:
                // right to right
                addHor(maxX_A, maxX_B, midY_A, refer.maxX - main.maxX)
            case .same:
                // nothing
                break
            case .bigger:
                // right to right
                addHor(maxX_B, maxX_A, midY_B, main.maxX - refer.maxX)
            }

        case .bigger:
            if compare(minX_A, maxX_B) == .bigger {
                // left to right
                addHor(minX_A, maxX_B, midY_A, main.minX - refer.maxX)
            } else {
                // left to left
                addHor(minX_B, minX_A, midY_A, main.minX - refer.minX)

                if compare(maxX_A, maxX_B) == .smaller {
                    // right to right
                    addHor(maxX_A, maxX_B, midY_A, refer.maxX - main.maxX)
                }
            }
        }

        /** 水平方向的线 END **/

        /** 竖直方向的线 START **/
        var verDatas: [LKMeasureResultVerLineData] = []
        func addVer(_ startY: CGFloat, _ endY: CGFloat, _ x: CGFloat, _ value: CGFloat) {
            verDatas.append(LKMeasureResultVerLineData(startY: startY, endY: endY, x: x, displayValue: value))
        }

        switch compare(minY_A, minY_B) {
        case .smaller:
            if compare(maxY_A, minY_B) == .smaller {
                // bottom to top
                addVer(maxY_A, minY_B, midX_A, refer.minY - main.maxY)
            } else {
                // maxY_A >= minY_B
                switch compare(maxY_A, maxY_B) {
                case .smaller:
                    // bottom to bottom
                    addVer(maxY_A, maxY_B, midX_A, refer.maxY - main.maxY)
                case .same:
                    // nothing
                    break
                case .bigger:
                    // bottom to bottom
                    addVer(maxY_B, maxY_A, midX_B, main.maxY - refer.maxY)
                    // top to top
                    addVer(minY_A, minY_B, midX_B, refer.minY - main.minY)
                }
            }

        case .same:
            switch compare(maxY_A, maxY_B) {
            case .smaller:
                // bottom to bottom
                addVer(maxY_A, maxY_B, midX_A, refer.maxY - main.maxY)
            case .same:
                // nothing
                break
            case .bigger:
                // bottom to bottom
                addVer(maxY_B, maxY_A, midX_B, main.maxY - refer.maxY)
            }

        case .bigger:
            if compare(minY_A, maxY_B) == .bigger {
                // top to bottom
                addVer(maxY_B, minY_A, midX_A, main.minY - refer.maxY)
            } else {
                // top to top
                addVer(minY_B, minY_A, midX_A, main.minY - refer.minY)

                if compare(maxY_A, maxY_B) == .smaller {
                    // bottom to bottom
                    addVer(maxY_A, maxY_B, midX_A, refer.maxY - main.maxY)
                }
            }
        }

        /** 竖直方向的线 END **/

        let horPath = CGMutablePath()
        let verPath = CGMutablePath()
        let handlerLength: CGFloat = 3
        for data in horDatas {
            horPath.move(to: CGPoint(x: data.startX, y: data.y))
            horPath.addLine(to: CGPoint(x: data.endX, y: data.y))

            // 线段两端的小把手
            horPath.move(to: CGPoint(x: data.startX + 0.5, y: data.y - handlerLength))
            horPath.addLine(to: CGPoint(x: data.startX + 0.5, y: data.y + handlerLength))
            horPath.move(to: CGPoint(x: data.endX - 0.5, y: data.y - handlerLength))
            horPath.addLine(to: CGPoint(x: data.endX - 0.5, y: data.y + handlerLength))

            let labelView = dequeueAvailableTextField()
            labelView.backgroundColor = .systemBlue
            labelView.textField.stringValue = NSString.lookin_string(from: data.displayValue, decimal: 2) ?? ""
            labelView.fitSize().setHeight(labelHeight).setMidX(data.startX + (data.endX - data.startX) / 2.0).setMaxY(data.y - 5)
        }
        for data in verDatas {
            verPath.move(to: CGPoint(x: data.x, y: data.startY))
            verPath.addLine(to: CGPoint(x: data.x, y: data.endY))

            // 线段两端的小把手
            verPath.move(to: CGPoint(x: data.x - handlerLength, y: data.startY + 0.5))
            verPath.addLine(to: CGPoint(x: data.x + handlerLength, y: data.startY + 0.5))
            verPath.move(to: CGPoint(x: data.x - handlerLength, y: data.endY - 0.5))
            verPath.addLine(to: CGPoint(x: data.x + handlerLength, y: data.endY - 0.5))

            let labelView = dequeueAvailableTextField()
            labelView.backgroundColor = NSColor(lookinRed: 209, green: 120, blue: 0, alpha: 1.0)
            labelView.textField.stringValue = NSString.lookin_string(from: data.displayValue, decimal: 2) ?? ""
            labelView.fitSize().setHeight(labelHeight).setMidY(data.startY + (data.endY - data.startY) / 2.0).setMaxX(data.x - 5)
            if checkOverlap(ofTargetLabelView: labelView) {
                labelView.setX(data.x + 5)
                // 给点透明度，至少能稍微看到后面重叠的文字
                labelView.backgroundColor = NSColor(lookinRed: 209, green: 120, blue: 0, alpha: 0.5)
            }
        }
        horSolidLinesLayer.path = horPath
        horSolidLinesLayer.isHidden = false
        verSolidLinesLayer.path = verPath
        verSolidLinesLayer.isHidden = false
    }

    private func checkOverlap(ofTargetLabelView targetView: NSView) -> Bool {
        for otherView in textFieldViews {
            if otherView === targetView {
                continue
            }
            if !otherView.isVisible {
                continue
            }
            let inter = otherView.frame.intersection(targetView.frame)
            if !inter.isNull && inter.size.width * inter.size.height > 100 {
                return true
            }
        }
        return false
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let minY = min(scaledMainFrame.minY, scaledReferFrame.minY)
        let maxY = max(scaledMainFrame.maxY, scaledReferFrame.maxY)
        let height = maxY - minY
        return NSSize(width: MeasureViewWidth, height: height + verInset * 2)
    }

    private func calculateScaleFactor(withMainRect mainRect: CGRect, referRect: CGRect) -> CGFloat {
        let maxContentWidth = MeasureViewWidth - horInset * 2
        let maxContentHeight = max(((window?.frame.size.height ?? 0) - LKNavigationManager.sharedInstance.windowTitleBarHeight) * 0.8, 200)

        let contentSize = size(fromRectA: mainRect, rectB: referRect)

        let scaleFactor_x = contentSize.width / maxContentWidth
        let scaleFactor_y = contentSize.height / maxContentHeight
        var scaleFactor = max(scaleFactor_x, scaleFactor_y)
        if scaleFactor <= 0 {
            scaleFactor = 1
            assertionFailure()
        }
        return scaleFactor
    }

    private func size(fromRectA rectA: CGRect, rectB: CGRect) -> CGSize {
        CGSize(width: max(rectA.maxX, rectB.maxX) - min(rectA.minX, rectB.minX), height: max(rectA.maxY, rectB.maxY) - min(rectA.minY, rectB.minY))
    }

    private func adjustRect(_ rect: CGRect, withScaleFactor factor: CGFloat) -> CGRect {
        var factor = factor
        if factor == 0 {
            assertionFailure()
            factor = 1
        }
        return CGRect(x: rect.origin.x / factor, y: rect.origin.y / factor, width: rect.size.width / factor, height: rect.size.height / factor)
    }

    private func hideAllLabels() {
        textFieldViews.forEach { $0.isHidden = true }
    }

    private func dequeueAvailableTextField() -> LKTextFieldView {
        let resultView: LKTextFieldView
        if let hiddenView = textFieldViews.first(where: { $0.isHidden }) {
            resultView = hiddenView
        } else {
            resultView = LKTextFieldView.labelView()
            resultView.insets = NSEdgeInsets(top: 0, left: 3, bottom: 0, right: 3)
            resultView.textField.textColor = .white
            resultView.textField.font = .systemFont(ofSize: 13)
            resultView.textField.alignment = .center
            resultView.layer?.cornerRadius = labelHeight / 2.0
            contentView.addSubview(resultView)
            textFieldViews.append(resultView)
        }
        resultView.isHidden = false
        return resultView
    }

    private func compare(_ a: CGFloat, _ b: CGFloat) -> CompareResult {
        if abs(a - b) < 0.00001 {
            return .same
        }
        return a > b ? .bigger : .smaller
    }
}
