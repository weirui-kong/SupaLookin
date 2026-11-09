//
//  SPLKServerActions.swift
//  SPLKServerSession
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SERVER

import Foundation
import UIKit
import SPLKProtocol
import SPLKModelBridge
import SPLKServer

@MainActor
enum SPLKServerActions {

    // Synthesized touches use IDs of their own, apart from Live Control's.
    private static let touchID: UInt = 900
    private static let defaultSettle: TimeInterval = 2

    static func perform(_ call: SPLKV2PerformAction) async throws -> SPLKV2ActionResult {
        let view = try target(call.oid)
        switch call.action {
        case .tap:
            if !view.accessibilityActivate() {
                if let control = view as? UIControl {
                    control.sendActions(for: .touchUpInside)
                } else {
                    try await touch(view, holding: 0, moving: .zero)
                }
            }
        case .longPress:
            try await touch(view, holding: 0.6, moving: .zero)
        case .setText:
            try setText(call.text, in: view)
        case .scrollToVisible:
            guard let scrollView = enclosingScrollView(of: view, includingSelf: false) else {
                throw failed("no_scroll_view", "No scroll view encloses this view.")
            }
            scrollView.scrollRectToVisible(view.convert(view.bounds, to: scrollView), animated: false)
        case .scrollBy:
            guard let scrollView = enclosingScrollView(of: view, includingSelf: true) else {
                throw failed("no_scroll_view", "Neither this view nor any view around it scrolls.")
            }
            scroll(scrollView, by: CGPoint(x: call.delta.x, y: call.delta.y))
        case .swipe:
            try await touch(view, holding: 0, moving: CGPoint(x: call.delta.x, y: call.delta.y))
        case .goBack:
            try goBack(from: view)
        case .unspecified, .UNRECOGNIZED:
            throw SPLKStatusError(.invalidArgument, reason: "unknown_action")
        }
        let timeout = call.settleTimeoutMs == 0 ? defaultSettle : TimeInterval(call.settleTimeoutMs) / 1000
        return await waitForIdle(timeout: timeout)
    }

    static func waitForIdle(timeout: TimeInterval) async -> SPLKV2ActionResult {
        var result = SPLKV2ActionResult()
        result.settled = await SPLKUIMonitor.shared.waitForIdle(timeout: timeout)
        result.hierarchyVersion = SPLKUIMonitor.shared.generation
        return result
    }

    // MARK: - Targets

    private static func target(_ oid: UInt64) throws -> UIView {
        if oid == 0, let root = SPLKServerRuntime.keyWindow()?.rootViewController?.view {
            return root
        }
        let object = SPLKServerOperations.liveObject(forOid: UInt(oid))
        if let view = object as? UIView {
            return view
        }
        if let view = (object as? CALayer)?.delegate as? UIView {
            return view
        }
        throw SPLKStatusError(.notFound, reason: SPLKBridge.Reason.objectDeallocated)
    }

    private static func failed(_ reason: String, _ title: String) -> SPLKStatusError {
        SPLKStatusError(.failedPrecondition, reason: reason, title: title)
    }

    // MARK: - Synthesized touches

    private static func touch(_ view: UIView, holding duration: TimeInterval, moving delta: CGPoint) async throws {
        guard SPLKTouchInjector.isTouchAvailable(), let window = view.window else {
            throw failed("touch_unavailable", "Touches can't be synthesized here.")
        }
        let start = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: window)
        func normalized(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x / window.bounds.width, y: point.y / window.bounds.height)
        }
        try SPLKTouchInjector.injectTouch(touchID, phase: .began, location: normalized(start))
        if duration > 0 {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        }
        var end = start
        if delta != .zero {
            let steps = 12
            for step in 1...steps {
                end = CGPoint(x: start.x + delta.x * CGFloat(step) / CGFloat(steps), y: start.y + delta.y * CGFloat(step) / CGFloat(steps))
                try SPLKTouchInjector.injectTouch(touchID, phase: .moved, location: normalized(end))
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
        try SPLKTouchInjector.injectTouch(touchID, phase: .ended, location: normalized(end))
    }

    // MARK: - Text

    private static func setText(_ text: String, in view: UIView) throws {
        guard let input = view as? (UIView & UITextInput), view.canBecomeFirstResponder else {
            throw failed("no_text_input", "This view doesn't take text input.")
        }
        view.becomeFirstResponder()
        if let all = input.textRange(from: input.beginningOfDocument, to: input.endOfDocument) {
            input.replace(all, withText: "")
        }
        input.insertText(text)
    }

    // MARK: - Scrolling

    private static func enclosingScrollView(of view: UIView, includingSelf: Bool) -> UIScrollView? {
        var current: UIView? = includingSelf ? view : view.superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView {
                return scrollView
            }
            current = candidate.superview
        }
        return nil
    }

    private static func scroll(_ scrollView: UIScrollView, by delta: CGPoint) {
        let insets = scrollView.adjustedContentInset
        let minimum = CGPoint(x: -insets.left, y: -insets.top)
        let maximum = CGPoint(
            x: max(minimum.x, scrollView.contentSize.width - scrollView.bounds.width + insets.right),
            y: max(minimum.y, scrollView.contentSize.height - scrollView.bounds.height + insets.bottom)
        )
        let offset = scrollView.contentOffset
        scrollView.setContentOffset(CGPoint(
            x: min(max(offset.x + delta.x, minimum.x), maximum.x),
            y: min(max(offset.y + delta.y, minimum.y), maximum.y)
        ), animated: false)
    }

    // MARK: - Navigation

    private static func goBack(from view: UIView) throws {
        var responder: UIResponder? = view
        while let current = responder, !(current is UIViewController) {
            responder = current.next
        }
        guard let controller = responder as? UIViewController else {
            throw failed("nothing_to_go_back", "No view controller owns this view.")
        }
        let navigation = controller as? UINavigationController ?? controller.navigationController
        if let navigation, navigation.viewControllers.count > 1 {
            navigation.popViewController(animated: true)
        } else if let presented = controller.presentedViewController {
            presented.dismiss(animated: true)
        } else if controller.presentingViewController != nil {
            controller.dismiss(animated: true)
        } else {
            throw failed("nothing_to_go_back", "There's nothing to go back from.")
        }
    }
}

#endif
