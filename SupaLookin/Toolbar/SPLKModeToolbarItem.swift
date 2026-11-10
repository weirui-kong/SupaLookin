//
//  SPLKModeToolbarItem.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Cocoa

let SPLKToolBarIdentifier_Mode = NSToolbarItem.Identifier("20")

// The mode pull-down left of Reload. Takeover can't be picked: agents start it, and the person can only end it.
final class SPLKModeToolbarItem: NSMenuToolbarItem {

    enum Choice: Equatable {
        case inspect, liveControl, endTakeover
    }

    struct Entry: Equatable {
        let choice: Choice
        let title: String
        let isEnabled: Bool
        let isChecked: Bool
        let toolTip: String?
    }

    var onSelect: ((Choice) -> Void)?

    init() {
        super.init(itemIdentifier: SPLKToolBarIdentifier_Mode)
        showsIndicator = true
        update(mode: .inspect, hasApp: false)
    }

    static func entries(mode: SPLKWindowMode, hasApp: Bool) -> [Entry] {
        let takeoverLabel: String? = {
            if case .takeover(let label) = mode { return label }
            return nil
        }()
        let isTakeover = takeoverLabel != nil
        var entries = [
            Entry(choice: .inspect, title: NSLocalizedString("Inspect", comment: ""), isEnabled: hasApp && !isTakeover, isChecked: mode == .inspect, toolTip: nil),
            Entry(choice: .liveControl, title: NSLocalizedString("Live Control", comment: ""), isEnabled: hasApp && !isTakeover, isChecked: mode == .liveControl, toolTip: nil),
        ]
        if let takeoverLabel {
            entries.append(Entry(choice: .endTakeover, title: String(format: NSLocalizedString("End Takeover by %@", comment: ""), takeoverLabel), isEnabled: hasApp, isChecked: false, toolTip: nil))
        } else {
            entries.append(Entry(choice: .endTakeover, title: NSLocalizedString("Takeover", comment: ""), isEnabled: false, isChecked: false, toolTip: NSLocalizedString("An agent starts Takeover by calling take_control.", comment: "")))
        }
        return entries
    }

    static func appearance(of mode: SPLKWindowMode) -> (symbol: String, label: String) {
        switch mode {
        case .inspect: return ("square.3.layers.3d", NSLocalizedString("Inspect", comment: ""))
        case .liveControl: return ("hand.tap", NSLocalizedString("Live Control", comment: ""))
        case .takeover(let label): return ("sparkles", label)
        }
    }

    func update(mode: SPLKWindowMode, hasApp: Bool) {
        let (symbol, label) = Self.appearance(of: mode)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        self.label = label
        paletteLabel = NSLocalizedString("Mode", comment: "")
        isEnabled = hasApp

        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, entry) in Self.entries(mode: mode, hasApp: hasApp).enumerated() {
            if index == 2 {
                menu.addItem(.separator())
            }
            let item = NSMenuItem(title: entry.title) { [weak self] _ in
                self?.onSelect?(entry.choice)
            }
            item.isEnabled = entry.isEnabled
            item.state = entry.isChecked ? .on : .off
            item.toolTip = entry.toolTip
            menu.addItem(item)
        }
        self.menu = menu
    }
}
