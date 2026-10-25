//
//  LKInputSearchSuggestionWindowController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/2.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKInputSearchSuggestionWindowController: LKWindowController {

    let suggestionsView: LKInputSearchSuggestionsContentView

    init() {
        let view = LKInputSearchSuggestionsContentView()

        let suggestionPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 100), styleMask: .utilityWindow, backing: .buffered, defer: true)
        suggestionPanel.contentView = view
        suggestionPanel.isFloatingPanel = true
        suggestionPanel.becomesKeyOnlyIfNeeded = true
        suggestionPanel.backgroundColor = .clear

        suggestionsView = view
        super.init(window: suggestionPanel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
