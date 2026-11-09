//
//  SPLKSplitView.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class SPLKSplitView: NSSplitView {

    private var hasLayouted = false

    var didFinishFirstLayout: ((SPLKSplitView) -> Void)?

    override var dividerThickness: CGFloat {
        0
    }

    override func layout() {
        super.layout()
        if !hasLayouted {
            didFinishFirstLayout?(self)
            hasLayouted = true
        }
    }
}
