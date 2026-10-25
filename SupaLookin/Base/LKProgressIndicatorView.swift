//
//  LKProgressIndicatorView.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/10/7.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

let InitialIndicatorProgressWhenFetchHierarchy: CGFloat = 0.7

final class LKProgressIndicatorView: LKBaseView {

    private let fillLayer = CALayer()

    // The animator proxy drives this through KVC, which needs it exposed to the Objective-C runtime.
    @objc dynamic private(set) var progress: CGFloat = 0 {
        didSet {
            fillLayer.setX(0).setWidth(frame.width * progress).setHeight(frame.height).setY(0)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        fillLayer.backgroundColor = LKHelper.accentColor.cgColor
        layer?.addSublayer(fillLayer)
        fillLayer.lookin_removeImplicitAnimations()
        progress = 0
    }

    override func layout() {
        super.layout()
        fillLayer.setX(0).setWidth(frame.width * progress).setHeight(frame.height).setY(0)
    }

    override func animation(forKey key: NSAnimatablePropertyKey) -> Any? {
        if key == "progress" {
            return CABasicAnimation()
        }
        return super.animation(forKey: key)
    }

    func resetToZero() {
        progress = 0
    }

    func animate(toProgress progress: CGFloat, duration: TimeInterval = 0.5) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            self.animator().progress = progress
        }
    }

    func finish(completion: (@MainActor () -> Void)?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            self.animator().progress = 1
        }, completionHandler: {
            if let completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.progress = 0
            }
        })
    }
}
