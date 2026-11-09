//
//  SPLKPreviewStageView.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/6.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

protocol SPLKPreviewStageViewDelegate: AnyObject {
    func previewStageView(_ view: SPLKPreviewStageView, mouseMoved event: NSEvent)
    func didResetCursorRects(in view: SPLKPreviewStageView)
}

final class SPLKPreviewStageView: SPLKBaseView {

    weak var delegate: SPLKPreviewStageViewDelegate?

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        delegate?.previewStageView(self, mouseMoved: event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        delegate?.didResetCursorRects(in: self)
    }
}
