//
//  LKHierarchyRowView.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKHierarchyRowView: LKOutlineRowView, @preconcurrency LookinDisplayItemDelegate {

    private let dataSource: LKHierarchyDataSource

    private var strikethroughLayer: CALayer?
    private var eventHandlerButtonColorLayer: CALayer?

    private var isFocusingHandlerButton = false {
        didSet {
            guard oldValue != isFocusingHandlerButton else { return }
            updateEventHandlerButtonLayout()
            updateEventHandlerButtonColors()
        }
    }

    /// 注意这里是 weak，因为 tableView 会缓存很多 rowView（macOS 下的 tableView 要比 iOS 里的 tableView 缓存的更多，因为屏幕大），如果这里是 strong 的话会导致 displayItem 不能随着 hierarchy reload 而被及时释放，而 displayItem 又 retain 了很多 image 这种占内存的东西，所以这里要写成 weak
    weak var displayItem: LookinDisplayItem? {
        willSet {
            if let newValue, newValue.rowViewDelegate !== self {
                // 在 displayItem 没变的情况下，displayItem.rowViewDelegate 仍然可能不指向 self，因此这里必须重新配置一下，否则会有 Bug：先选中一个 view 并进入 focus 状态，然后退出 focus，然后就发现那个 view 的选中态无法取消
                newValue.rowViewDelegate = self
            }
        }
        didSet {
            if oldValue !== displayItem {
                reRender()
            }
        }
    }

    var minIndentLevel = 0

    /// 左侧的小蓝条图标
    private(set) var eventHandlerButton: NSButton?

    init(dataSource: LKHierarchyDataSource) {
        self.dataSource = dataSource
        super.init(compactUI: false)
    }

    override func layout() {
        super.layout()

        eventHandlerButton?.setY(3).extendToBottom(3).setWidth(10).setX(3)
        updateEventHandlerButtonLayout()

        if let strikethroughLayer, !strikethroughLayer.isHidden {
            let maxX = subtitleLabel.isHidden ? (titleLabel.frame.maxX + 2) : subtitleLabel.frame.maxX + 2
            strikethroughLayer.setHeight(1).setX(titleLabel.frame.minX - 1).extendToMaxX(maxX).setMidY(titleLabel.frame.midY + 1)
        }
    }

    func reRender() {
        guard let displayItem else {
            return
        }
        isRowSelected = (dataSource.selectedItem === displayItem)
        isHovered = (dataSource.hoveredItem === displayItem)
        image = resolveIconImage()
        indentLevel = displayItem.indentLevel() - minIndentLevel
        updateEventsButton()
        updateExpandStatus()
        updateStrikethroughLayer()
        updateLabelStringsAndImageViewAlpha()
        updateLabelsFonts()

        needsLayout = true
    }

    override var isHovered: Bool {
        didSet {
            updateEventHandlerButtonColors()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateEventHandlerButtonColors()
    }

    // MARK: - Event Handler

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        isFocusingHandlerButton = point.x < 16
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isFocusingHandlerButton = false
    }

    private func handleClickEventHandlerButton(_ button: NSButton) {
        LKTutorialManager.sharedInstance.eventsHandler = true

        guard let displayItem else {
            return
        }
        let popover = NSPopover()

        let editable = window != nil && window === LKNavigationManager.sharedInstance.staticWindowController?.window

        let vc = LKHierarchyHandlersPopoverController(displayItem: displayItem, editable: editable)
        popover.animates = false
        popover.behavior = .transient
        popover.contentSize = vc.neededSize()
        popover.contentViewController = vc
        popover.show(relativeTo: NSRect(x: 0, y: 0, width: button.bounds.size.width, height: button.bounds.size.height), of: button, preferredEdge: .maxY)
    }

    private func updateLabelStringsAndImageViewAlpha() {
        let titleColor: NSColor
        let subtitleColor: NSColor

        if isRowSelected {
            titleColor = .white
            subtitleColor = .white
            imageView.alphaValue = 1
        } else if resolveIfShouldFadeContent() {
            titleColor = .tertiaryLabelColor
            subtitleColor = .tertiaryLabelColor
            imageView.alphaValue = 0.6
        } else {
            titleColor = .labelColor
            subtitleColor = .secondaryLabelColor
            imageView.alphaValue = 1
        }

        var titleString = LKAttributedStringBuilder(displayItem?.title).textColor(titleColor).attributedString
        var subtitleString = LKAttributedStringBuilder(displayItem?.subtitle).textColor(subtitleColor).attributedString

        if let displayItem, displayItem.isInSearch, let highlightedSearchString = displayItem.highlightedSearchString, !highlightedSearchString.isEmpty {
            // 搜索状态下，且命中了搜索词
            let bgColor = isDarkMode ? NSColor(lookinRed: 190, green: 120, blue: 0) : NSColor(lookinRed: 255, green: 240, blue: 100)
            let attrs: [NSAttributedString.Key: Any] = [.backgroundColor: bgColor, .foregroundColor: NSColor.labelColor]

            if let string = titleString {
                let titleHighlightRange = (string.string as NSString).range(of: highlightedSearchString, options: .caseInsensitive)
                if titleHighlightRange.location != NSNotFound {
                    let mutable = NSMutableAttributedString(attributedString: string)
                    mutable.addAttributes(attrs, range: titleHighlightRange)
                    titleString = mutable
                }
            }

            if let string = subtitleString {
                let subtitleHighlightRange = (string.string as NSString).range(of: highlightedSearchString, options: .caseInsensitive)
                if subtitleHighlightRange.location != NSNotFound {
                    let mutable = NSMutableAttributedString(attributedString: string)
                    mutable.addAttributes(attrs, range: subtitleHighlightRange)
                    subtitleString = mutable
                }
            }
        }
        titleLabel.attributedStringValue = titleString ?? NSAttributedString()
        subtitleLabel.attributedStringValue = subtitleString ?? NSAttributedString()
    }

    private func updateEventsButton() {
        guard let displayItem, (displayItem.eventHandlers?.count ?? 0) > 0 else {
            eventHandlerButton?.isHidden = true
            return
        }
        if eventHandlerButton == nil {
            let button = NSButton()
            button.title = ""
            button.onAction { [weak self] button in
                self?.handleClickEventHandlerButton(button)
            }
            button.wantsLayer = true
            button.isBordered = false
            button.bezelStyle = .roundRect
            button.layer?.backgroundColor = NSColor.clear.cgColor
            addSubview(button)
            eventHandlerButton = button

            let colorLayer = CALayer()
            colorLayer.actions = ["contents": NSNull()]
            button.layer?.addSublayer(colorLayer)
            eventHandlerButtonColorLayer = colorLayer
        }
        eventHandlerButton?.isHidden = false
        updateEventHandlerButtonColors()
    }

    // MARK: - LookinDisplayItemDelegate

    func displayItem(_ displayItem: LookinDisplayItem, propertyDidChange property: LookinDisplayItemProperty) {
        if property == .isHovered {
            isHovered = (dataSource.hoveredItem === self.displayItem)
        } else {
            reRender()
        }
    }

    private func updateStrikethroughLayer() {
        if resolveIfShouldShowStrikethrough() {
            let layer: CALayer
            if let strikethroughLayer {
                layer = strikethroughLayer
            } else {
                layer = CALayer()
                layer.lookin_removeImplicitAnimations()
                self.layer?.addSublayer(layer)
                strikethroughLayer = layer
            }
            if isRowSelected {
                layer.backgroundColor = NSColor.white.withAlphaComponent(0.75).cgColor
            } else {
                layer.backgroundColor = isDarkMode ? NSColor(lookinRed: 255, green: 255, blue: 255, alpha: 0.2).cgColor : NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.2).cgColor
            }
            layer.isHidden = false
            needsLayout = true
        } else {
            strikethroughLayer?.isHidden = true
        }
    }

    private func resolveIfShouldShowStrikethrough() -> Bool {
        guard let item = displayItem else {
            return false
        }
        if !item.hasPreviewBoxAbility {
            return false
        }
        return item.inNoPreviewHierarchy
    }

    override func isDarkModeDidChange() {
        super.isDarkModeDidChange()
        updateStrikethroughLayer()
    }

    private func updateEventHandlerButtonColors() {
        guard let eventHandlerButton, !eventHandlerButton.isHidden else {
            return
        }
        let color: NSColor
        if isRowSelected {
            color = .white
        } else {
            let alpha: CGFloat = isFocusingHandlerButton ? 1 : 0.5
            color = NSColor(lookinRed: 74, green: 144, blue: 226, alpha: alpha)
        }
        eventHandlerButtonColorLayer?.backgroundColor = color.cgColor
    }

    private func updateEventHandlerButtonLayout() {
        let width: CGFloat = isFocusingHandlerButton ? 8 : 5
        eventHandlerButtonColorLayer?.fillHeight().setWidth(width).centerHorizontally()
        eventHandlerButtonColorLayer?.cornerRadius = width / 2.0
    }

    private func updateLabelsFonts() {
        let noImage = (displayItem?.inNoPreviewHierarchy ?? false) || (displayItem?.inHiddenHierarchy ?? false)
        if !(displayItem?.isUserCustom ?? false) && noImage {
            titleLabel.font = LKHelper.italicFont(ofSize: 13)
            subtitleLabel.font = LKHelper.italicFont(ofSize: 12)
        } else {
            titleLabel.font = .systemFont(ofSize: 13)
            subtitleLabel.font = .systemFont(ofSize: 12)
        }
        needsLayout = true
    }

    private func updateExpandStatus() {
        guard let displayItem else {
            status = .notExpandable
            return
        }
        if !displayItem.isExpandable {
            status = .notExpandable
        } else if displayItem.isExpanded {
            status = .expanded
        } else {
            status = .collapsed
        }
    }

    // MARK: - Others

    private static let viewsList: [(String, String)] = [
        ("UIWindow", "hierarchy_window"),
        ("UINavigationBar", "hierarchy_navigationbar"),
        ("UITabBar", "hierarchy_tabbar"),
        ("UITextView", "hierarchy_textview"),
        ("UIStackView", "hierarchy_stackview"),
        ("UITextField", "hierarchy_textfield"),
        ("UITableView", "hierarchy_tableview"),
        ("UICollectionView", "hierarchy_collectionview"),
        ("UICollectionViewCell", "hierarchy_collectioncell"),
        ("UICollectionReusableView", "hierarchy_collectionreuseview"),
        ("UITableViewCell", "hierarchy_tablecell"),
        ("UISlider", "hierarchy_slider"),
        ("WKWebView", "hierarchy_webview"),
        ("UIWebView", "hierarchy_webview"),
        ("_UITableViewCellSeparatorView", "hierarchy_tablecellseparator"),
        ("UITableViewCellContentView", "hierarchy_cellcontent"),
        ("_UITableViewHeaderFooterContentView", "hierarchy_cellcontent"),
        ("UITableViewHeaderFooterView", "hierarchy_tableheaderfooter"),
        ("UIScrollView", "hierarchy_scrollview"),
        ("UILabel", "hierarchy_label"),
        ("UIButton", "hierarchy_button"),
        ("UIImageView", "hierarchy_imageview"),
        ("UIControl", "hierarchy_control"),
        ("UIVisualEffectView", "hierarchy_effectview"),
    ]

    private func resolveIconImage() -> NSImage? {
        guard let item = displayItem else {
            return nil
        }
        var imageName: String?
        if item.isUserCustom {
            imageName = "hierarchy_custom"

        } else if item.hostViewControllerObject != nil {
            imageName = "hierarchy_controller"

        } else if let viewObject = item.viewObject {
            for className in viewObject.classChainList ?? [] {
                if let match = Self.viewsList.first(where: { $0.0 == className }) {
                    imageName = match.1
                    break
                }
            }
            if imageName == nil {
                imageName = "hierarchy_view"
            }

        } else if let layerObject = item.layerObject {
            for className in layerObject.classChainList ?? [] {
                if className == "CAShapeLayer" {
                    imageName = "hierarchy_shapelayer"
                    break
                }
                if className == "CAGradientLayer" {
                    imageName = "hierarchy_gradientlayer"
                    break
                }
            }
            if imageName == nil {
                imageName = "hierarchy_layer"
            }
        }

        let name = imageName ?? "hierarchy_view"
        if dataSource.selectedItem === displayItem {
            return NSImage(named: name + "_selected") ?? NSImage(named: name)
        }
        return NSImage(named: name)
    }

    private func resolveIfShouldFadeContent() -> Bool {
        guard let item = displayItem else {
            return false
        }
        if item.isInSearch && (item.highlightedSearchString ?? "").isEmpty {
            return true
        }
        if !item.hasPreviewBoxAbility {
            return false
        }
        return item.inHiddenHierarchy || item.inNoPreviewHierarchy
    }

    override class var insetLeft: CGFloat {
        13
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        // The Objective-C code passed NSEventTypeMouseExited (raw 9) as a tracking option; the same raw bits are kept.
        let options: NSTrackingArea.Options = [NSTrackingArea.Options(rawValue: NSEvent.EventType.mouseExited.rawValue), .mouseMoved, .activeInKeyWindow, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }
}
