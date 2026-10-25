//
//  LKTutorialManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/27.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

private let Key_TogglePreview = "Tut_2"
private let Key_QuickSelection = "Tut_5"
private let Key_MoveWithSpace = "Tut_6"
private let Key_CopyTitle = "Tut_8"
private let Key_EventsHandler = "Tut_EventsHandler"
private let Key_DoubleClickBehavior = "Tut_DoubleClickBehavior"

final class LKTutorialManager: NSObject, NSPopoverDelegate {

    static let sharedInstance = LKTutorialManager()

    var togglePreview: Bool {
        didSet {
            if oldValue != togglePreview {
                UserDefaults.standard.set(togglePreview, forKey: Key_TogglePreview)
            }
        }
    }

    var quickSelection: Bool {
        didSet {
            if oldValue != quickSelection {
                UserDefaults.standard.set(quickSelection, forKey: Key_QuickSelection)
            }
        }
    }

    var moveWithSpace: Bool {
        didSet {
            if oldValue != moveWithSpace {
                UserDefaults.standard.set(moveWithSpace, forKey: Key_MoveWithSpace)
            }
        }
    }

    var copyTitle: Bool {
        didSet {
            if oldValue != copyTitle {
                UserDefaults.standard.set(copyTitle, forKey: Key_CopyTitle)
            }
        }
    }

    var eventsHandler: Bool {
        didSet {
            if oldValue != eventsHandler {
                UserDefaults.standard.set(eventsHandler, forKey: Key_EventsHandler)
            }
        }
    }

    var hasAskedDoubleClickBehavior: Bool {
        didSet {
            UserDefaults.standard.set(hasAskedDoubleClickBehavior, forKey: Key_DoubleClickBehavior)
        }
    }

    var hasAlreadyShowedTipsThisLaunch = false

    private override init() {
        let userDefaults = UserDefaults.standard

        togglePreview = userDefaults.bool(forKey: Key_TogglePreview)
        quickSelection = userDefaults.bool(forKey: Key_QuickSelection)
        moveWithSpace = userDefaults.bool(forKey: Key_MoveWithSpace)
        copyTitle = userDefaults.bool(forKey: Key_CopyTitle)
        eventsHandler = userDefaults.bool(forKey: Key_EventsHandler)
        hasAskedDoubleClickBehavior = userDefaults.bool(forKey: Key_DoubleClickBehavior)
        super.init()
    }

    func showPopover(ofView view: NSView, text: String, learned learnedBlock: (() -> Void)?) {
        let popover = NSPopover()

        let vc = LKTutorialPopoverController(text: text, popover: popover)
        vc.learnedBlock = learnedBlock
        popover.delegate = self
        popover.animates = true
        popover.behavior = .transient
        popover.contentSize = vc.contentSize()
        popover.contentViewController = vc
        popover.show(relativeTo: NSRect(x: 0, y: 0, width: view.bounds.size.width, height: view.bounds.size.height), of: view, preferredEdge: .maxY)
        vc.showTimestamp = Date().timeIntervalSince1970
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        guard let popover = notification.object as? NSPopover else {
            assertionFailure()
            return
        }
        guard let tutorialVC = popover.contentViewController as? LKTutorialPopoverController else {
            assertionFailure()
            return
        }
        if tutorialVC.hasClickedCloseButton || (Date().timeIntervalSince1970 - tutorialVC.showTimestamp > 1.8) {
            tutorialVC.learnedBlock?()
        }
    }
}
