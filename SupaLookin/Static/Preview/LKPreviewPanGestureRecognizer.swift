//
//  LKPreviewPanGestureRecognizer.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/31.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

enum PreviewPanGesturePurpose {
    case rotate
    case translate
}

final class LKPreviewPanGestureRecognizer: NSPanGestureRecognizer {

    /// 默认为 rotate
    var purpose: PreviewPanGesturePurpose = .rotate
    var initialRotation: CGPoint = .zero
    var initialTranslation: NSPoint = .zero
}
