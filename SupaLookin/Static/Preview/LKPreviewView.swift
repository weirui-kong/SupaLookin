//
//  LKPreviewView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/17.
//  https://lookin.work
//
//  该类的代码实现，借鉴甚至直接复制了很多 https://github.com/TalkingData/YourView 项目的 SceneKit 相关代码
//  Lookin 项目鸣谢：https://qxh1ndiez2w.feishu.cn/docx/YIFjdE4gIolp3hxn1tGckiBxnWf
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

//  Lookin 项目鸣谢：https://qxh1ndiez2w.feishu.cn/docx/YIFjdE4gIolp3hxn1tGckiBxnWf

import Cocoa
import SceneKit
import LookinShared

let LookinPreviewMinScale: CGFloat = 0
let LookinPreviewMaxScale: CGFloat = 1
let LookinPreviewMinZInterspace: CGFloat = 0
let LookinPreviewMaxZInterspace: CGFloat = 1

enum LookinPreviewDimension: Int {
    case dimension2D
    case dimension3D
}

final class LKPreviewView: SCNView {

    private let dataSource: LKHierarchyDataSource
    private let stageNode = SCNNode()
    private let cameraNode = SCNNode()
    private let rightLightNode = SCNNode()
    private let leftLightNode = SCNNode()
    private var flatDisplayItems: [LookinDisplayItem] = []
    private var displayItemNodes: [LKDisplayItemNode] = []

    /// Plays the role of LookinDisplayItem.previewNode, which Swift can't assign because it's typed with a forward-declared class.
    private let previewNodes = NSMapTable<LookinDisplayItem, LKDisplayItemNode>.weakToWeakObjects()

    /// rotation.x 是左右旋转的角度，rotation.y 是上下旋转的角度
    private(set) var rotation: CGPoint = .zero

    /// 上下移动的距离
    var translation: CGPoint = .zero {
        didSet {
            var position = stageNode.position
            position.x = translation.x
            position.y = translation.y
            stageNode.position = position
        }
    }

    /// 图像大小，最小值是 LookinPreviewMinScale，最大值是 LookinPreviewMaxScale
    var scale: CGFloat = 0 {
        didSet {
            /**
             focalLength 越小则图像越小，focalLength 越大则图像越大
             传入的 scale 是 0 ~ 1，会把 focalLength 映射为 20 ~ 750
             */
            cameraNode.camera?.focalLength = 20 + scale * scale * 730
        }
    }

    /// 图层之间的纵向间距，最小值是 LookinPreviewMinZInterspace，最大值是 LookinPreviewMaxZInterspace
    var zInterspace: CGFloat = 0 {
        didSet {
            let clamped = min(max(zInterspace, LookinPreviewMinZInterspace), LookinPreviewMaxZInterspace)
            if clamped != zInterspace {
                zInterspace = clamped
                return
            }
            updateZPositionByZIndex()
        }
    }

    /// 设置 2D 和 3D 模式，置为 2D 会使得 rotation 变成 0，置为 3D 不会改变 rotation
    private(set) var dimension: LookinPreviewDimension = .dimension2D

    /// iOS App 的屏幕大小
    var appScreenSize: CGSize = .zero {
        didSet {
            guard oldValue != appScreenSize else { return }

            var rightPos = rightLightNode.position
            rightPos.x = appScreenSize.width * 0.01 * 0.5 + 2
            rightPos.y = appScreenSize.height * 0.01 * 0.5 + 2
            rightLightNode.position = rightPos

            var leftPos = leftLightNode.position
            leftPos.x = -appScreenSize.width * 0.01 * 0.5 - 2
            leftPos.y = -appScreenSize.height * 0.01 * 0.5 - 2
            leftLightNode.position = leftPos
            displayItemNodes.forEach { $0.screenSize = appScreenSize }
        }
    }

    var preferenceManager: LKPreferenceManager?

    var isDarkMode = false {
        didSet {
            backgroundColor = isDarkMode ? NSColor(lookinRed: 19, green: 20, blue: 21) : NSColor(lookinRed: 249, green: 249, blue: 249)
            displayItemNodes.forEach { $0.isDarkMode = isDarkMode }
        }
    }

    var showHiddenItems = false

    init(dataSource: LKHierarchyDataSource) {
        self.dataSource = dataSource
        super.init(frame: .zero, options: nil)

        allowsCameraControl = false
        showsStatistics = false

        let scene = SCNScene()
        self.scene = scene

        stageNode.name = "stage"
        scene.rootNode.addChildNode(stageNode)

        cameraNode.name = "camera"
        let camera = SCNCamera()
        camera.automaticallyAdjustsZRange = true
        cameraNode.camera = camera
        // 这里的 position.z 决定了畸变的程度，即“近大远小”的程度
        cameraNode.position = SCNVector3(0, 0, 34)
        scene.rootNode.addChildNode(cameraNode)

        let rightLight = SCNLight()
        rightLight.type = .omni
        rightLight.categoryBitMask = Int(LookinPreviewBitMask.hasLight.rawValue)
        rightLightNode.name = "right light"
        rightLightNode.light = rightLight
        scene.rootNode.addChildNode(rightLightNode)

        let leftLight = SCNLight()
        leftLight.type = .spot
        leftLight.categoryBitMask = Int(LookinPreviewBitMask.hasLight.rawValue)
        leftLightNode.name = "left light"
        // The Objective-C code assigned rightLight here too, so leftLight is never used.
        leftLightNode.light = rightLight
        scene.rootNode.addChildNode(leftLightNode)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 通过 items 来构建对应的 node，items 里不应该包含 noPreview 为 true 的 item
    /// 如果 discardCache 为 true，则会丢弃本次渲染未用到的 node 对象。如果 discardCache 为 false，则本次渲染未用到的 node 对象会被隐藏起来但不会被丢弃，从而供以后使用
    func render(withDisplayItems items: [LookinDisplayItem], discardCache: Bool) {
        NSLog("LKPreviewView - render %@ items", NSNumber(value: items.count))

        flatDisplayItems = items

        var nodesToBeDiscarded: [LKDisplayItemNode] = []

        displayItemNodes.dequeue(count: items.count, add: { _ in
            let newNode = LKDisplayItemNode(dataSource: dataSource)
            newNode.screenSize = appScreenSize
            newNode.preferenceManager = preferenceManager
            newNode.isDarkMode = isDarkMode
            stageNode.addChildNode(newNode)
            return newNode
        }, notDequeued: { _, node in
            node.removeFromParentNode()
            if discardCache {
                nodesToBeDiscarded.append(node)
            }
        }, doNext: { idx, node in
            if node.parent == nil {
                stageNode.addChildNode(node)
            }
            let displayItem = items[idx]
            previewNodes.setObject(node, forKey: displayItem)
            node.index = idx
            node.displayItem = displayItem
        })

        if !nodesToBeDiscarded.isEmpty {
            displayItemNodes.removeAll { node in nodesToBeDiscarded.contains { $0 === node } }
        }

        updateZPosition()
    }

    /**
     重新计算每个 item 的 zIndex，并依 zIndex 设置对应的图层在 z 轴上的 translation。同时根据 fold 等属性来显示或隐藏图层。
     */
    func updateZPosition() {
        flatDisplayItems.forEach { updateZIndex(for: $0) }
        updateZPositionByZIndex()
    }

    private func updateZPositionByZIndex() {
        let interspace: CGFloat
        if dimension == .dimension2D {
            interspace = 0.01
        } else {
            interspace = 0.1 + zInterspace * 0.7
        }

        // key 是 zIndex，value 是该 zIndex 下有多少 item，作用是避免下文提到的 offsetToAvoidOverlapBug
        var zIndexAndCountDict: [Int: Int] = [:]

        var maxZIndex = 0
        for node in displayItemNodes {
            maxZIndex = max(maxZIndex, node.displayItem?.previewZIndex ?? 0)
        }
        let zIndexOffset = Int((Double(maxZIndex) * 0.5).rounded())

        // 没这个 SCNTransaction 的话，收起、展开时图像没动画
        SCNTransaction.begin()

        for node in displayItemNodes {
            let previewZIndex = node.displayItem?.previewZIndex ?? 0
            // 将 "1, 2, 3, 4, 5 ..." 这样的 zIndex 排序调整为 “-2，-1，0，1，2 ...”，这样旋转时 Y 轴就会位于 zIndex 为中间值的那个 layer 的位置
            let adjustedZIndex = previewZIndex - zIndexOffset

            let countOfCurrentZIndex = zIndexAndCountDict[adjustedZIndex] ?? 0
            zIndexAndCountDict[adjustedZIndex] = countOfCurrentZIndex + 1

            // 当 zIndex 相同时，把更靠近用户的那个 layer 的 zIndex 增大一丁点，从而避免重叠
            let offsetToAvoidOverlapBug = CGFloat(countOfCurrentZIndex) * 0.0001

            var position = node.position
            position.z = CGFloat(adjustedZIndex) * interspace + offsetToAvoidOverlapBug
            node.position = position
        }

        // 切记：要把 SCNTransaction commit 放到 for 循环外面，不能放到 for 循环里面。否则短时间内大量细碎的 SCNTransaction 会导致渲染很慢
        SCNTransaction.commit()
    }

    private func updateZIndex(for item: LookinDisplayItem) {
        item.previewZIndex = -1
        if item.displayingInHierarchy {
            if let referenceItem = maxZIndexForOverlappedItem(under: item) {
                // 如果 item 和另一个 itemA 重叠了，则 item.previewZIndex 应该比 itemA.previewZIndex 高一级
                item.previewZIndex = referenceItem.previewZIndex + 1
            } else {
                item.previewZIndex = 0
            }
        } else {
            if let superItem = item.`super` {
                item.previewZIndex = superItem.previewZIndex
            } else {
                assertionFailure()
            }
        }

        if item.previewZIndex < 0 {
            assertionFailure()
            item.previewZIndex = 0
        }
    }

    /**
     传入 itemA，返回另一个 itemB，itemB 满足以下条件：
     - itemB 在 preview 中可见
     - itemB 的层级比 itemA 要低（即 itemB 在 flatItems 里的 index 要比 itemA 小）
     - itemB 和 itemA 的 frameToRoot 有重叠，即视觉上它们是彼此遮挡的
     - itemB 是满足以上两个条件中的所有 items 里的 zIndex 值最高的

     如果没有找到任何符合条件的 itemB，则返回 nil
     */
    private func maxZIndexForOverlappedItem(under item: LookinDisplayItem) -> LookinDisplayItem? {
        guard let itemIndex = flatDisplayItems.firstIndex(where: { $0 === item }) else {
            assertionFailure()
            return nil
        }
        if itemIndex == 0 {
            return nil
        }
        let itemFrameToRoot = item.calculateFrameToRoot()
        var targetItem: LookinDisplayItem?
        for obj in flatDisplayItems[0..<itemIndex].reversed() {
            if !obj.inHiddenHierarchy || showHiddenItems {
                if itemFrameToRoot.intersects(obj.calculateFrameToRoot()) {
                    if let currentTarget = targetItem {
                        if obj.previewZIndex > currentTarget.previewZIndex {
                            targetItem = obj
                        }
                    } else {
                        targetItem = obj
                    }
                }
            }
        }
        return targetItem
    }

    func didSelectItem(_ item: LookinDisplayItem?) {
        guard let item else {
            return
        }

        let nodeZ = previewNodes.object(forKey: item)?.position.z ?? 0

        var rightPos = rightLightNode.position
        rightPos.z = nodeZ + 2
        rightLightNode.position = rightPos

        var leftPos = leftLightNode.position
        leftPos.z = nodeZ + 2
        leftLightNode.position = leftPos
    }

    func displayItem(at point: CGPoint) -> LookinDisplayItem? {
        let hitResults = hitTest(point, options: [
            .categoryBitMask: Int(LookinPreviewBitMask.selectable.rawValue),
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .ignoreHiddenNodes: false,
        ])
        guard let result = hitResults.first else {
            return nil
        }
        let targetNode = result.node.parent as? LKDisplayItemNode
        assert(targetNode != nil)
        return targetNode?.displayItem
    }

    /// duration 为 0 时表示使用系统默认时长（即 0.25s）
    func setRotation(_ rotation: CGPoint, animated: Bool, timingFunction function: CAMediaTimingFunction? = nil, duration: CGFloat = 0) {
        self.rotation = rotation

        let equivalentRotation = Self.equivalentRotation(from: rotation)

        let angles = SCNVector3(rotation.y, rotation.x, 0)

        if animated {
            SCNTransaction.begin()
            if duration > 0 {
                SCNTransaction.animationDuration = duration
            }
            if let function {
                SCNTransaction.animationTimingFunction = function
            }
            SCNTransaction.completionBlock = { [weak self] in
                MainActor.assumeIsolated {
                    self?.rotation = equivalentRotation
                }
            }
            stageNode.eulerAngles = angles
            SCNTransaction.commit()
        } else {
            stageNode.eulerAngles = angles
            self.rotation = equivalentRotation
        }
    }

    func setDimension(_ dimension: LookinPreviewDimension, animated: Bool) {
        self.dimension = dimension

        if dimension == .dimension2D {
            setRotation(.zero, animated: animated)
        }

        updateZPositionByZIndex()
    }

    /// 把 rotation 转换为 -180 ～ 180 以内的角度（不包含 -180 本身），注意这里传入和传出的都是弧度制
    private static func equivalentRotation(from rotation: CGPoint) -> CGPoint {
        CGPoint(x: equivalentRotationValue(from: rotation.x), y: equivalentRotationValue(from: rotation.y))
    }

    private static func equivalentRotationValue(from rotation: CGFloat) -> CGFloat {
        var rotation = rotation
        while rotation <= -.pi {
            rotation += .pi * 2
        }
        while rotation >= .pi {
            rotation -= .pi * 2
        }
        return rotation
    }
}
