//
//  LKDisplayItemNode.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/17.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SceneKit
import LookinShared

final class LKDisplayItemNode: SCNNode, @preconcurrency LookinDisplayItemDelegate {

    private let dataSource: LKHierarchyDataSource
    private let contentNode: SCNNode
    private let contentPlane = SCNPlane()
    private var borderGeometry: SCNGeometry?
    private let borderNode = SCNNode()
    private let maskNode: SCNNode
    private let maskPlane = SCNPlane()

    private var borderColor: NSColor? {
        didSet {
            renderBorderColor()
        }
    }

    /// 在全部 displayItems 里的 idx
    var index = 0 {
        didSet {
            contentNode.renderingOrder = index * 10
            maskNode.renderingOrder = index * 10 + 1
            borderNode.renderingOrder = index * 10 + 2
        }
    }

    var screenSize: CGSize = .zero

    weak var preferenceManager: LKPreferenceManager? {
        didSet {
            preferenceManager?.showHiddenItems.subscribe(self) { node, _ in node.renderVisibility() }
            preferenceManager?.showOutline.subscribe(self) { node, _ in node.renderImageAndColor() }
            preferenceManager?.isQuickSelecting.subscribe(self) { node, _ in node.renderVisibility() }
        }
    }

    var displayItem: LookinDisplayItem? {
        didSet {
            // 不能把 contents 设置成 nil，否则某些场景下会发生内容渲染错乱的情况
            contentPlane.firstMaterial?.diffuse.contents = displayItem?.backgroundColor ?? NSColor.clear

            // 这一句会使得 displayItem(_:propertyDidChange:) 被立即调用，参数是 .none
            displayItem?.previewItemDelegate = self
        }
    }

    var isDarkMode = false {
        didSet {
            renderImageAndColor()
        }
    }

    init(dataSource: LKHierarchyDataSource) {
        self.dataSource = dataSource
        contentNode = SCNNode(geometry: contentPlane)
        maskNode = SCNNode(geometry: maskPlane)
        super.init()

        contentPlane.firstMaterial?.isDoubleSided = true
        contentPlane.firstMaterial?.lightingModel = .constant
        contentPlane.firstMaterial?.diffuse.contents = NSColor.clear
        contentNode.position = SCNVector3(0, 0, 0)
        contentNode.name = "screenshot"
        contentNode.categoryBitMask = Int(LookinPreviewBitMask.noLight.rawValue)
        addChildNode(contentNode)

        // 注意这里并没有 add maskNode，需要的时候再 add
        maskPlane.firstMaterial?.isDoubleSided = true
        maskNode.name = "mask"
        maskNode.position = SCNVector3(0, 0, 0.001)
        maskNode.categoryBitMask = Int(LookinPreviewBitMask.hasLight.rawValue)

        borderNode.name = "border"
        borderNode.position = SCNVector3(0, 0, 0.002)
        borderNode.categoryBitMask = Int(LookinPreviewBitMask.noLight.rawValue)
        addChildNode(borderNode)
    }

    // SCNNode's initializers are nonisolated, so these overrides must be too.
    @available(*, unavailable)
    nonisolated override init() {
        fatalError("init() has not been implemented")
    }

    @available(*, unavailable)
    nonisolated required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func renderBorderColor() {
        borderGeometry?.firstMaterial?.diffuse.contents = borderColor
    }

    private func makeBorderGeometry(withPlaneNode planeNode: SCNNode) -> SCNGeometry {
        let (min, max) = planeNode.boundingBox
        let xx = max.x - min.x
        let yy = max.y - min.y
        let vec = [
            max,
            SCNVector3(max.x, max.y - yy, max.z),
            SCNVector3(max.x - xx, max.y - yy, max.z),
            SCNVector3(max.x - xx, max.y, max.z),
        ]
        let indexs: [UInt8] = [0, 1, 1, 2, 2, 3, 3, 0]
        let vecSource = SCNGeometrySource(vertices: vec)
        let indexData = Data(indexs)
        let indexElement = SCNGeometryElement(data: indexData, primitiveType: .line, primitiveCount: 4, bytesPerIndex: MemoryLayout<UInt8>.size)
        let geometry = SCNGeometry(sources: [vecSource], elements: [indexElement])
        geometry.firstMaterial?.isDoubleSided = true
        geometry.firstMaterial?.lightingModel = .constant
        return geometry
    }

    private func renderVisibility() {
        let displayingInHierarchy = displayItem?.displayingInHierarchy ?? false
        let inHiddenHierarchy = displayItem?.inHiddenHierarchy ?? false
        let showEvenWhenCollapsed = (preferenceManager?.isQuickSelecting.currentBOOLValue ?? false) && !(displayItem?.`super`?.preferToBeCollapsed ?? false)
        let showHiddenItems = preferenceManager?.showHiddenItems.currentBOOLValue ?? false

        let canSelect: Bool
        if inHiddenHierarchy && !showHiddenItems {
            contentNode.opacity = 0
            borderNode.opacity = 0
            maskNode.isHidden = true
            canSelect = false
        } else if displayingInHierarchy {
            contentNode.opacity = 1
            borderNode.opacity = 1
            maskNode.isHidden = false
            canSelect = true
        } else {
            contentNode.opacity = 0
            maskNode.isHidden = true
            if showEvenWhenCollapsed {
                borderNode.opacity = 1
                canSelect = true
            } else {
                borderNode.opacity = 0
                canSelect = false
            }
        }

        if canSelect {
            contentNode.categoryBitMask = Int(LookinPreviewBitMask([.selectable, .noLight]).rawValue)
        } else {
            contentNode.categoryBitMask = Int(LookinPreviewBitMask([.unselectable, .noLight]).rawValue)
        }
    }

    private func renderImageAndColor() {
        let isSelected = displayItem != nil && dataSource.selectedItem === displayItem
        let isHovered = displayItem != nil && dataSource.hoveredItem === displayItem

        let appropriateScreenshot = displayItem?.appropriateScreenshot
        if let representation = appropriateScreenshot?.representations.first {
            assert(Double(Swift.max(representation.pixelsWide, representation.pixelsHigh)) <= LookinNodeImageMaxLengthInPx, "image is too large")
        }
        contentPlane.firstMaterial?.diffuse.contents = appropriateScreenshot

        let tooLargeToFetchScreenshot = appropriateScreenshot == nil && displayItem?.doNotFetchScreenshotReason == .doNotFetchScreenshotForTooLarge

        // 更新 border 颜色
        if isSelected || isHovered {
            if tooLargeToFetchScreenshot {
                borderColor = NSColor(lookinRed: 255, green: 38, blue: 0, alpha: 0.8)
            } else {
                borderColor = NSColor(lookinRed: 100, green: 146, blue: 199)
            }
        } else if preferenceManager?.showOutline.currentBOOLValue ?? false {
            if tooLargeToFetchScreenshot {
                borderColor = isDarkMode ? NSColor(lookinRed: 255, green: 38, blue: 0, alpha: 0.5) : NSColor(lookinRed: 255, green: 38, blue: 0, alpha: 0.6)
            } else {
                borderColor = isDarkMode ? NSColor(lookinRed: 160, green: 168, blue: 189, alpha: 0.6) : NSColor(lookinRed: 120, green: 122, blue: 124, alpha: 0.6)
            }
        } else {
            borderColor = .clear
        }

        // 更新 mask 颜色
        let maskColor: NSColor
        var maskOpacity: CGFloat = 0
        if tooLargeToFetchScreenshot {
            maskColor = NSColor(lookinRed: 255, green: 38, blue: 0)
            if isSelected {
                maskOpacity = 0.45
            } else if isHovered {
                maskOpacity = 0.3
            } else {
                maskOpacity = isDarkMode ? 0.17 : 0.2
            }
        } else {
            maskColor = NSColor(lookinRed: 110, green: 183, blue: 255)
            var level = LKPreferenceManager.mainManager.imageContrastLevel
            if level < 0 || level > 2 {
                assertionFailure()
                level = 0
            }
            if isSelected {
                maskOpacity = [0.35, 0.6, 0.85][level]
            } else if isHovered {
                maskOpacity = [0.18, 0.38, 0.6][level]
            } else {
                maskOpacity = 0
            }
        }
        if maskOpacity > 0 && maskNode.parent == nil {
            insertChildNode(maskNode, at: 1)
        }
        maskNode.opacity = maskOpacity
        maskPlane.firstMaterial?.diffuse.contents = maskColor
    }

    // MARK: - LookinDisplayItemDelegate

    func displayItem(_ displayItem: LookinDisplayItem, propertyDidChange property: LookinDisplayItemProperty) {
        if property == .none || property == .frameToRoot {
            let frameToRoot = displayItem.calculateFrameToRoot()

            let originX = frameToRoot.origin.x
            let originY = frameToRoot.origin.y
            let width = frameToRoot.size.width
            let height = frameToRoot.size.height
            let xOffSet = -screenSize.width / 2
            let yOffSet = screenSize.height / 2
            let transformedX = originX + width / 2 + xOffSet
            let transformedY = -(originY + height / 2) + yOffSet

            let factor: CGFloat = 0.01

            contentPlane.width = width * factor
            contentPlane.height = height * factor

            maskPlane.width = contentPlane.width
            maskPlane.height = contentPlane.height

            var position = self.position
            position.x = transformedX * factor
            position.y = transformedY * factor
            self.position = position

            let geometry = makeBorderGeometry(withPlaneNode: contentNode)
            borderGeometry = geometry
            borderNode.geometry = geometry
            renderBorderColor()
        }

        switch property {
        case .none, .isExpandable, .isExpanded, .soloScreenshot, .groupScreenshot, .isSelected, .isHovered, .avoidSyncScreenshot:
            renderImageAndColor()
        default:
            break
        }

        if property == .none || property == .displayingInHierarchy || property == .inHiddenHierarchy {
            renderVisibility()
        }
    }
}
