//
//  LKPreferenceManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/1/8.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

let LKWindowSizeName_Dynamic = "LKWindowSizeName_Dynamic"
let LKWindowSizeName_Static = "LKWindowSizeName_Static"

/// 初始的 preview scale
let LKInitialPreviewScale: CGFloat = 0.27

/// 当某个 section 被添加或移除时，会发出该通知
let NotificationName_DidChangeSectionShowing = Notification.Name("NotificationName_DidChangeSectionShowing")

enum LookinPreferredAppeanranceType: Int {
    case dark
    case light
    case system
}

enum LookinDoubleClickBehavior: Int {
    case collapse
    case focus
}

enum LookinPreferredCallStackType: Int {
    /// 格式化 + 简略
    case `default`
    /// 格式化 + 完整
    case formattedCompletely
    /// 原始堆栈
    case raw
}

enum LookinMeasureState: Int {
    /// 没有处于测距模式
    case no
    /// 处于测距模式，但未锁定，此时松开手指就会导致退出测距模式
    case unlocked
    /// 处于测距模式，且锁定，此时松开手指不会退出测距模式
    case locked
}

private let Key_PreviousClientVersion = "preVer"
private let Key_ShowOutline = "showOutline"
private let Key_ShowHiddenItems = "showHiddenItems"
private let Key_RgbaFormat = "egbaFormat"
private let Key_ZInterspace = "zInterspace_v095"
private let Key_AppearanceType = "appearanceType"
private let Key_DoubleClickBehavior = "doubleClickBehavior"
private let Key_ExpansionIndex = "expansionIndex"
private let Key_ContrastLevel = "contrastLevel"
private let Key_SectionsShow = "ss"
private let Key_CollapsedGroups = "collapsedGroups_918"
private let Key_PreferredExportCompression = "preferredExportCompression"
private let Key_SyncConsoleTarget = "syncConsoleTarget"
private let Key_FreeRotation = "FreeRotation"
private let Key_FastMode = "fastMode"
private let Key_ReceivingConfigTime_Color = "ConfigTime_Color"
private let Key_ReceivingConfigTime_Class = "ConfigTime_Class"

final class LKPreferenceManager {

    static let mainManager: LKPreferenceManager = {
        let manager = LKPreferenceManager()
        manager.shouldStoreToLocal = true
        return manager
    }()

    private let userDefaults: UserDefaults

    /// 默认为 false
    var shouldStoreToLocal = false

    var appearanceType: LookinPreferredAppeanranceType {
        didSet {
            defer { appearanceTypeObservation.notify() }
            guard oldValue != appearanceType else { return }
            if shouldStoreToLocal {
                userDefaults.set(appearanceType.rawValue, forKey: Key_AppearanceType)
            }
        }
    }

    var doubleClickBehavior: LookinDoubleClickBehavior {
        didSet {
            if shouldStoreToLocal {
                userDefaults.set(doubleClickBehavior.rawValue, forKey: Key_DoubleClickBehavior)
            }
        }
    }

    /// 有效值为 0 ～ 4
    var expansionIndex: Int {
        didSet {
            guard oldValue != expansionIndex else { return }
            if shouldStoreToLocal {
                userDefaults.set(expansionIndex, forKey: Key_ExpansionIndex)
            }
        }
    }

    let showOutline: LookinBOOLMsgAttribute
    let showHiddenItems: LookinBOOLMsgAttribute

    // 范围是 0 ～ 1
    let zInterspace: LookinDoubleMsgAttribute

    var rgbaFormat: Bool {
        didSet {
            defer { rgbaFormatObservation.notify() }
            guard oldValue != rgbaFormat else { return }
            if shouldStoreToLocal {
                userDefaults.set(rgbaFormat, forKey: Key_RgbaFormat)
            }
        }
    }

    /// 0 ~ 2
    var imageContrastLevel: Int {
        didSet {
            guard oldValue != imageContrastLevel else { return }
            if shouldStoreToLocal {
                userDefaults.set(imageContrastLevel, forKey: Key_ContrastLevel)
            }
        }
    }

    /// 是否自动将选中的 UIView/CALayer 作为控制台的目标对象
    var syncConsoleTarget: Bool {
        didSet {
            defer { syncConsoleTargetObservation.notify() }
            guard oldValue != syncConsoleTarget else { return }
            if shouldStoreToLocal {
                userDefaults.set(syncConsoleTarget, forKey: Key_SyncConsoleTarget)
            }
        }
    }

    // 被折叠的 AttrGroup
    var collapsedAttrGroups: [String] {
        didSet {
            if shouldStoreToLocal {
                userDefaults.set(collapsedAttrGroups, forKey: Key_CollapsedGroups)
            }
        }
    }

    var preferredExportCompression: CGFloat {
        didSet {
            defer { preferredExportCompressionObservation.notify() }
            guard oldValue != preferredExportCompression else { return }
            if shouldStoreToLocal {
                userDefaults.set(Double(preferredExportCompression), forKey: Key_PreferredExportCompression)
            }
        }
    }

    let freeRotation: LookinBOOLMsgAttribute
    let fastMode: LookinBOOLMsgAttribute

    /// 上次接收到 iOS app 里传过来的 color config 和 collapsedClasses 信息的时间，用来统计
    var receivingConfigTime_Color: TimeInterval {
        didSet {
            userDefaults.set(receivingConfigTime_Color, forKey: Key_ReceivingConfigTime_Color)
        }
    }

    var receivingConfigTime_Class: TimeInterval {
        didSet {
            userDefaults.set(receivingConfigTime_Class, forKey: Key_ReceivingConfigTime_Class)
        }
    }

    private var storedSectionShowConfig: [String: Bool]

    private lazy var appearanceTypeObservation = LKKVOSubject { [unowned self] in self.appearanceType }
    private lazy var rgbaFormatObservation = LKKVOSubject { [unowned self] in self.rgbaFormat }
    private lazy var syncConsoleTargetObservation = LKKVOSubject { [unowned self] in self.syncConsoleTarget }
    private lazy var preferredExportCompressionObservation = LKKVOSubject { [unowned self] in self.preferredExportCompression }

    var appearanceTypePublisher: AnyPublisher<LookinPreferredAppeanranceType, Never> { appearanceTypeObservation.publisher }
    var rgbaFormatPublisher: AnyPublisher<Bool, Never> { rgbaFormatObservation.publisher }
    var syncConsoleTargetPublisher: AnyPublisher<Bool, Never> { syncConsoleTargetObservation.publisher }
    var preferredExportCompressionPublisher: AnyPublisher<CGFloat, Never> { preferredExportCompressionObservation.publisher }

    // MARK: - 以下属性不会持久化

    var callStackType: LookinPreferredCallStackType = .default

    let previewDimension: LookinIntegerMsgAttribute
    let previewScale: LookinDoubleMsgAttribute

    /// 参数是 LookinMeasureState
    let measureState: LookinIntegerMsgAttribute

    /// 是否用户正在按住 cmd 键而处于快速选择模式
    let isQuickSelecting: LookinBOOLMsgAttribute

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        previewScale = LookinDoubleMsgAttribute(double: Double(LKInitialPreviewScale))
        previewDimension = LookinIntegerMsgAttribute(integer: LookinPreviewDimension.dimension3D.rawValue)
        measureState = LookinIntegerMsgAttribute(integer: LookinMeasureState.no.rawValue)
        isQuickSelecting = LookinBOOLMsgAttribute(bool: false)

        let prevClientVersion = userDefaults.integer(forKey: Key_PreviousClientVersion)
        if prevClientVersion != Int(LOOKIN_CLIENT_VERSION) {
            userDefaults.set(Int(LOOKIN_CLIENT_VERSION), forKey: Key_PreviousClientVersion)
        }

        if let value = userDefaults.object(forKey: Key_ShowOutline) as? NSNumber {
            showOutline = LookinBOOLMsgAttribute(bool: value.boolValue)
        } else {
            showOutline = LookinBOOLMsgAttribute(bool: true)
            userDefaults.set(true, forKey: Key_ShowOutline)
        }

        if let value = userDefaults.object(forKey: Key_ShowHiddenItems) as? NSNumber {
            showHiddenItems = LookinBOOLMsgAttribute(bool: value.boolValue)
        } else {
            showHiddenItems = LookinBOOLMsgAttribute(bool: false)
            userDefaults.set(false, forKey: Key_ShowHiddenItems)
        }

        if let value = userDefaults.object(forKey: Key_DoubleClickBehavior) as? NSNumber {
            doubleClickBehavior = LookinDoubleClickBehavior(rawValue: Int(value.int32Value)) ?? .collapse
        } else {
            doubleClickBehavior = .collapse
            userDefaults.set(LookinDoubleClickBehavior.collapse.rawValue, forKey: Key_DoubleClickBehavior)
        }

        if let value = userDefaults.object(forKey: Key_RgbaFormat) as? NSNumber {
            rgbaFormat = value.boolValue
        } else {
            rgbaFormat = true
            userDefaults.set(true, forKey: Key_RgbaFormat)
        }

        var zInterspaceValue: Double
        if let value = userDefaults.object(forKey: Key_ZInterspace) as? NSNumber {
            zInterspaceValue = value.doubleValue
        } else {
            // 默认值为 0.22
            zInterspaceValue = 0.22
            userDefaults.set(zInterspaceValue, forKey: Key_ZInterspace)
        }
        zInterspaceValue = max(min(zInterspaceValue, Double(LookinPreviewMaxZInterspace)), Double(LookinPreviewMinZInterspace))
        zInterspace = LookinDoubleMsgAttribute(double: zInterspaceValue)

        if let value = userDefaults.object(forKey: Key_AppearanceType) as? NSNumber {
            appearanceType = LookinPreferredAppeanranceType(rawValue: value.intValue) ?? .system
        } else {
            appearanceType = .system
            userDefaults.set(LookinPreferredAppeanranceType.system.rawValue, forKey: Key_AppearanceType)
        }

        if let value = userDefaults.object(forKey: Key_ExpansionIndex) as? NSNumber {
            expansionIndex = value.intValue
        } else {
            expansionIndex = 3
            userDefaults.set(3, forKey: Key_ExpansionIndex)
        }

        if let value = userDefaults.object(forKey: Key_ContrastLevel) as? NSNumber {
            imageContrastLevel = value.intValue
        } else {
            imageContrastLevel = 0
            userDefaults.set(0, forKey: Key_ContrastLevel)
        }

        if let value = userDefaults.object(forKey: Key_SyncConsoleTarget) as? NSNumber {
            syncConsoleTarget = value.boolValue
        } else {
            syncConsoleTarget = true
            userDefaults.set(true, forKey: Key_SyncConsoleTarget)
        }

        if let value = userDefaults.object(forKey: Key_FreeRotation) as? NSNumber {
            freeRotation = LookinBOOLMsgAttribute(bool: value.boolValue)
        } else {
            freeRotation = LookinBOOLMsgAttribute(bool: true)
            userDefaults.set(true, forKey: Key_FreeRotation)
        }

        if let value = userDefaults.object(forKey: Key_FastMode) as? NSNumber {
            fastMode = LookinBOOLMsgAttribute(bool: value.boolValue)
        } else {
            fastMode = LookinBOOLMsgAttribute(bool: false)
            userDefaults.set(false, forKey: Key_FastMode)
        }

        storedSectionShowConfig = (userDefaults.object(forKey: Key_SectionsShow) as? [String: Bool]) ?? [:]

        collapsedAttrGroups = (userDefaults.object(forKey: Key_CollapsedGroups) as? [String]) ?? [LookinAttrGroup_Class]

        if let value = userDefaults.object(forKey: Key_PreferredExportCompression) as? NSNumber {
            preferredExportCompression = CGFloat(value.doubleValue)
        } else {
            // 这里的默认值需要在 LKExportAccessoryView 里定义的选项里面
            preferredExportCompression = 0.5
            userDefaults.set(0.5, forKey: Key_PreferredExportCompression)
        }

        receivingConfigTime_Color = userDefaults.double(forKey: Key_ReceivingConfigTime_Color)
        receivingConfigTime_Class = userDefaults.double(forKey: Key_ReceivingConfigTime_Class)

        // The Objective-C init subscribed showOutline's handler to showHiddenItems before that attribute existed, so the
        // subscription was a no-op and showOutline was never persisted. Only the later subscriptions took effect.
        showHiddenItems.subscribe(self) { manager, param in
            if manager.shouldStoreToLocal {
                manager.userDefaults.set(param.boolValue, forKey: Key_ShowHiddenItems)
            }
        }
        zInterspace.subscribe(self) { manager, param in
            if manager.shouldStoreToLocal {
                manager.userDefaults.set(param.doubleValue, forKey: Key_ZInterspace)
            }
        }
        freeRotation.subscribe(self) { manager, param in
            if manager.shouldStoreToLocal {
                manager.userDefaults.set(param.boolValue, forKey: Key_FreeRotation)
            }
        }
        fastMode.subscribe(self) { manager, param in
            if manager.shouldStoreToLocal {
                manager.userDefaults.set(param.boolValue, forKey: Key_FastMode)
            }
        }
    }

    /// 返回某个 section 是否应该被显示在主界面上
    func isSectionShowing(_ secID: String) -> Bool {
        if let stored = storedSectionShowConfig[secID] {
            return stored
        }
        return Self.showingSecIDsInDefault.contains(secID)
    }

    /// 把某个 section 显示在主界面上
    func showSection(_ secID: String) {
        if isSectionShowing(secID) {
            assertionFailure()
            return
        }
        storedSectionShowConfig[secID] = true
        NotificationCenter.default.post(name: NotificationName_DidChangeSectionShowing, object: nil)
        userDefaults.set(storedSectionShowConfig, forKey: Key_SectionsShow)
    }

    /// 把某个 section 从主界面上移除
    func hideSection(_ secID: String) {
        if !isSectionShowing(secID) {
            assertionFailure()
            return
        }
        storedSectionShowConfig[secID] = false
        NotificationCenter.default.post(name: NotificationName_DidChangeSectionShowing, object: nil)
        userDefaults.set(storedSectionShowConfig, forKey: Key_SectionsShow)
    }

    /// 返回默认情况下，哪些 section 应该被显示在主界面上
    private static let showingSecIDsInDefault: Set<String> = [
        LookinAttrSec_Class_Class,

        LookinAttrSec_Relation_Relation,

        LookinAttrSec_Layout_Frame,
        LookinAttrSec_Layout_Bounds,

        LookinAttrSec_AutoLayout_Hugging,
        LookinAttrSec_AutoLayout_Resistance,
        LookinAttrSec_AutoLayout_Constraints,
        LookinAttrSec_AutoLayout_IntrinsicSize,

        LookinAttrSec_ViewLayer_Visibility,
        LookinAttrSec_ViewLayer_InterationAndMasks,
        LookinAttrSec_ViewLayer_Corner,
        LookinAttrSec_ViewLayer_BgColor,
        LookinAttrSec_ViewLayer_Border,
        LookinAttrSec_ViewLayer_Shadow,

        LookinAttrSec_UIStackView_Axis,
        LookinAttrSec_UIStackView_Alignment,
        LookinAttrSec_UIStackView_Distribution,
        LookinAttrSec_UIStackView_Spacing,

        LookinAttrSec_UIVisualEffectView_Style,
        LookinAttrSec_UIVisualEffectView_QMUIForegroundColor,

        LookinAttrSec_UIImageView_Name,
        LookinAttrSec_UIImageView_Open,

        LookinAttrSec_UILabel_Text,
        LookinAttrSec_UILabel_Font,
        LookinAttrSec_UILabel_NumberOfLines,
        LookinAttrSec_UILabel_TextColor,
        LookinAttrSec_UILabel_BreakMode,
        LookinAttrSec_UILabel_Alignment,

        LookinAttrSec_UIControl_EnabledSelected,
        LookinAttrSec_UIControl_QMUIOutsideEdge,

        LookinAttrSec_UIButton_ContentInsets,

        LookinAttrSec_UIScrollView_ContentInset,
        LookinAttrSec_UIScrollView_AdjustedInset,
        LookinAttrSec_UIScrollView_IndicatorInset,
        LookinAttrSec_UIScrollView_Offset,
        LookinAttrSec_UIScrollView_ContentSize,
        LookinAttrSec_UIScrollView_Behavior,

        LookinAttrSec_UITableView_Style,
        LookinAttrSec_UITableView_SectionsNumber,
        LookinAttrSec_UITableView_RowsNumber,

        LookinAttrSec_UITextView_Text,
        LookinAttrSec_UITextView_Font,
        LookinAttrSec_UITextView_TextColor,
        LookinAttrSec_UITextView_Alignment,
        LookinAttrSec_UITextView_ContainerInset,

        LookinAttrSec_UITextField_Text,
        LookinAttrSec_UITextField_Font,
        LookinAttrSec_UITextField_TextColor,
        LookinAttrSec_UITextField_Alignment,
    ]

    /// 如果之前没弹过“双击图层时你希望发生什么？”这个框，则这个方法会弹框且返回 true。否则该方法什么都不会做且返回 false
    @discardableResult
    static func popupToAskDoubleClickBehaviorIfNeeded(with window: NSWindow?) -> Bool {
        guard let window else {
            return false
        }
        if LKTutorialManager.sharedInstance.hasAskedDoubleClickBehavior {
            return false
        }
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("What do you want to happen when you double click the layer?", comment: "")
        alert.informativeText = NSLocalizedString("You can change it at any time in your Preferences.", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("Expand or collapse layer", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Focus on layer", comment: ""))
        alert.beginSheetModal(for: window) { returnCode in
            if returnCode == .alertFirstButtonReturn {
                // collapse
                LKPreferenceManager.mainManager.doubleClickBehavior = .collapse
            } else {
                // focus
                LKPreferenceManager.mainManager.doubleClickBehavior = .focus
            }
        }
        LKTutorialManager.sharedInstance.hasAskedDoubleClickBehavior = true
        return true
    }

    func reset() {
        LKTutorialManager.sharedInstance.hasAskedDoubleClickBehavior = false
    }
}
