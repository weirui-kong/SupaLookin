//
//  LKFrameLayout.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa

extension CGFloat {

    /// Rounds up to the backing pixel grid, e.g. at 2x: 0.1 => 0.5, 1.3 => 1.5
    var snappedToPixel: CGFloat {
        if self == .leastNormalMagnitude || self == .greatestFiniteMagnitude {
            return self
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 1
        return ceil(self * scale) / scale
    }

    fileprivate var nanGuarded: CGFloat {
        if isNaN {
            assertionFailure("传入了 NaN")
            return 0
        }
        return self
    }
}

extension NSSize {
    static let max = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
}

/// Frame-based layout shared by NSView and CALayer.
protocol LKFrameLayout: AnyObject {
    var frame: CGRect { get set }
    var layoutBoundsSize: CGSize { get }
    var layoutSuperBoundsSize: CGSize? { get }
    var layoutSuperIsFlipped: Bool { get }
}

extension NSView: LKFrameLayout {
    var layoutBoundsSize: CGSize { bounds.size }
    var layoutSuperBoundsSize: CGSize? { superview?.bounds.size }
    var layoutSuperIsFlipped: Bool { superview?.isFlipped ?? false }
}

extension CALayer: LKFrameLayout {
    var layoutBoundsSize: CGSize { bounds.size }
    var layoutSuperBoundsSize: CGSize? { superlayer?.bounds.size }
    var layoutSuperIsFlipped: Bool { superlayer?.contentsAreFlipped() ?? false }
}

extension LKFrameLayout {

    @discardableResult
    func setX(_ value: CGFloat) -> Self {
        frame.origin.x = value.nanGuarded.snappedToPixel
        return self
    }

    @discardableResult
    func setY(_ value: CGFloat) -> Self {
        frame.origin.y = value.nanGuarded.snappedToPixel
        return self
    }

    @discardableResult
    func setWidth(_ value: CGFloat) -> Self {
        frame.size.width = value.nanGuarded.snappedToPixel
        return self
    }

    @discardableResult
    func setHeight(_ value: CGFloat) -> Self {
        frame.size.height = value.nanGuarded.snappedToPixel
        return self
    }

    @discardableResult
    func setSize(_ size: CGSize) -> Self {
        setWidth(size.width).setHeight(size.height)
    }

    @discardableResult
    func setOrigin(_ origin: CGPoint) -> Self {
        setX(origin.x).setY(origin.y)
    }

    @discardableResult
    func setFrame(_ rect: CGRect) -> Self {
        setOrigin(rect.origin).setSize(rect.size)
    }

    @discardableResult
    func offset(x: CGFloat = 0, y: CGFloat = 0) -> Self {
        let x = x.nanGuarded
        let y = y.nanGuarded
        frame.origin.x = (frame.minX + x).snappedToPixel
        frame.origin.y = (frame.minY + y).snappedToPixel
        return self
    }

    @discardableResult
    func setMidX(_ value: CGFloat) -> Self {
        setX(value.nanGuarded - layoutBoundsSize.width / 2)
    }

    @discardableResult
    func setMaxX(_ value: CGFloat) -> Self {
        setX(value.nanGuarded - layoutBoundsSize.width)
    }

    @discardableResult
    func setMidY(_ value: CGFloat) -> Self {
        setY(value.nanGuarded - layoutBoundsSize.height / 2)
    }

    @discardableResult
    func setMaxY(_ value: CGFloat) -> Self {
        setY(value.nanGuarded - layoutBoundsSize.height)
    }

    @discardableResult
    func alignRight(_ value: CGFloat) -> Self {
        guard let superSize = layoutSuperBoundsSize else {
            assertionFailure("必须存在 superview 才可使用该方法")
            return self
        }
        return setMaxX(superSize.width - value.nanGuarded)
    }

    @discardableResult
    func alignBottom(_ value: CGFloat) -> Self {
        guard let superSize = layoutSuperBoundsSize else {
            assertionFailure("必须存在 superview 才可使用该方法")
            return self
        }
        if layoutSuperIsFlipped {
            return setMaxY(superSize.height - value.nanGuarded)
        }
        return setY(value.nanGuarded)
    }

    @discardableResult
    func centerHorizontally() -> Self {
        guard let superSize = layoutSuperBoundsSize else {
            assertionFailure("必须存在 superview 才可使用该方法")
            return self
        }
        return setMidX(superSize.width / 2)
    }

    @discardableResult
    func centerVertically() -> Self {
        guard let superSize = layoutSuperBoundsSize else {
            assertionFailure("必须存在 superview 才可使用该方法")
            return self
        }
        return setMidY(superSize.height / 2)
    }

    @discardableResult
    func centerInSuperview() -> Self {
        centerVertically().centerHorizontally()
    }

    @discardableResult
    func fillWidth() -> Self {
        setX(0).extendToRight(0)
    }

    @discardableResult
    func fillHeight() -> Self {
        guard let superSize = layoutSuperBoundsSize else {
            assertionFailure("必须存在 superview 才可使用该方法")
            return self
        }
        return setHeight(superSize.height).setY(0)
    }

    @discardableResult
    func fillSuperview() -> Self {
        fillWidth().fillHeight()
    }

    @discardableResult
    func extendToX(_ value: CGFloat) -> Self {
        let safeValue = min(value.nanGuarded, frame.maxX)
        var rect = frame
        rect.size.width = (rect.maxX - safeValue).snappedToPixel
        rect.origin.x = safeValue.snappedToPixel
        frame = rect
        return self
    }

    @discardableResult
    func extendToMaxX(_ value: CGFloat) -> Self {
        let safeValue = max(value.nanGuarded, frame.minX)
        frame.size.width = (safeValue - frame.minX).snappedToPixel
        return self
    }

    @discardableResult
    func extendToY(_ value: CGFloat) -> Self {
        let safeValue = min(value.nanGuarded, frame.maxY)
        var rect = frame
        rect.size.height = (rect.maxY - safeValue).snappedToPixel
        rect.origin.y = safeValue.snappedToPixel
        frame = rect
        return self
    }

    @discardableResult
    func extendToMaxY(_ value: CGFloat) -> Self {
        let safeValue = max(value.nanGuarded, frame.minY)
        frame.size.height = (safeValue - frame.minY).snappedToPixel
        return self
    }

    @discardableResult
    func extendToRight(_ value: CGFloat) -> Self {
        let superWidth = layoutSuperBoundsSize?.width ?? 0
        frame.size.width = max((superWidth - frame.minX - value.nanGuarded).snappedToPixel, 0)
        return self
    }

    @discardableResult
    func extendToBottom(_ value: CGFloat) -> Self {
        guard let superSize = layoutSuperBoundsSize else {
            assertionFailure("必须存在 superview 才可使用该方法")
            return self
        }
        if layoutSuperIsFlipped {
            return extendToMaxY(superSize.height - value.nanGuarded)
        }
        return extendToY(value.nanGuarded)
    }

    @discardableResult
    func limitWidth(max maxWidth: CGFloat) -> Self {
        guard !maxWidth.isNaN else {
            assertionFailure("传入了 NaN")
            return self
        }
        if frame.width > maxWidth {
            frame.size.width = maxWidth
        }
        return self
    }

    @discardableResult
    func limitWidth(min minWidth: CGFloat) -> Self {
        guard !minWidth.isNaN else {
            assertionFailure("传入了 NaN")
            return self
        }
        if frame.width < minWidth {
            frame.size.width = minWidth
        }
        return self
    }
}

extension NSView {

    /// Matches ShortCocoa's `sizeToFit`: only LKBaseView and NSControl are sized, through `sizeThatFits(_:)`.
    @discardableResult
    func fitSize() -> Self {
        if let view = self as? LKBaseView {
            frame.size = view.sizeThatFits(.max)
        } else if let control = self as? NSControl {
            var size = control.sizeThatFits(.max)
            if size.width.isNaN {
                size.width = 0
            }
            if size.height.isNaN {
                size.height = 0
            }
            frame.size = size
        }
        return self
    }

    /// Matches ShortCocoa's `widthToFit`: only LKBaseView and NSControl are sized, through `sizeThatFits(_:)`.
    @discardableResult
    func fitWidth() -> Self {
        let limitedSize = NSSize(width: .greatestFiniteMagnitude, height: bounds.height)
        if let view = self as? LKBaseView {
            frame.size.width = view.sizeThatFits(limitedSize).width
        } else if let control = self as? NSControl {
            frame.size.width = control.sizeThatFits(limitedSize).width
        }
        return self
    }

    /// Matches ShortCocoa's `heightToFit`: only LKBaseView and NSControl are sized, through `sizeThatFits(_:)`.
    @discardableResult
    func fitHeight() -> Self {
        let limitedSize = NSSize(width: bounds.width, height: .greatestFiniteMagnitude)
        if let view = self as? LKBaseView {
            frame.size.height = view.sizeThatFits(limitedSize).height
        } else if let control = self as? NSControl {
            frame.size.height = control.sizeThatFits(limitedSize).height
        }
        return self
    }
}

extension Array where Element: LKFrameLayout {

    private var isInSameCoordinate: Bool {
        guard let first else {
            return false
        }
        if count == 1 {
            return true
        }
        let sameParent: Bool
        if let view = first as? NSView {
            sameParent = allSatisfy { ($0 as? NSView)?.superview === view.superview && view.superview != nil }
        } else if let layer = first as? CALayer {
            sameParent = allSatisfy { ($0 as? CALayer)?.superlayer === layer.superlayer && layer.superlayer != nil }
        } else {
            sameParent = false
        }
        assert(sameParent, "包装了多个对象，但它们没有相同的 superview")
        return sameParent
    }

    var groupMinX: CGFloat {
        guard isInSameCoordinate else { return 0 }
        return map(\.frame.minX).min() ?? 0
    }

    var groupMaxX: CGFloat {
        guard isInSameCoordinate else { return 0 }
        return map(\.frame.maxX).max() ?? 0
    }

    var groupMinY: CGFloat {
        guard isInSameCoordinate else { return 0 }
        return map(\.frame.minY).min() ?? 0
    }

    var groupMaxY: CGFloat {
        guard isInSameCoordinate else { return 0 }
        return map(\.frame.maxY).max() ?? 0
    }

    var groupMidX: CGFloat {
        guard isInSameCoordinate else { return 0 }
        return groupMinX + (groupMaxX - groupMinX) / 2
    }

    var groupMidY: CGFloat {
        guard isInSameCoordinate else { return 0 }
        return groupMinY + (groupMaxY - groupMinY) / 2
    }

    var groupWidth: CGFloat {
        guard isInSameCoordinate else { return 0 }
        return groupMaxX - groupMinX
    }

    var groupHeight: CGFloat {
        guard isInSameCoordinate else { return 0 }
        return groupMaxY - groupMinY
    }

    var groupSize: CGSize {
        guard isInSameCoordinate else { return .zero }
        return CGSize(width: groupWidth, height: groupHeight)
    }

    func offset(x: CGFloat = 0, y: CGFloat = 0) {
        forEach { $0.offset(x: x, y: y) }
    }

    func setGroupX(_ value: CGFloat) {
        offset(x: value - groupMinX)
    }

    func setGroupMidX(_ value: CGFloat) {
        offset(x: value - groupMidX)
    }

    func setGroupMaxX(_ value: CGFloat) {
        offset(x: value - groupMaxX)
    }

    func setGroupY(_ value: CGFloat) {
        offset(y: value - groupMinY)
    }

    func setGroupMidY(_ value: CGFloat) {
        offset(y: value - groupMidY)
    }

    func setGroupMaxY(_ value: CGFloat) {
        offset(y: value - groupMaxY)
    }

    func centerGroupHorizontally() {
        guard isInSameCoordinate, let superSize = first?.layoutSuperBoundsSize else { return }
        setGroupMidX(superSize.width / 2)
    }

    func centerGroupVertically() {
        guard isInSameCoordinate, let superSize = first?.layoutSuperBoundsSize else { return }
        setGroupMidY(superSize.height / 2)
    }
}
