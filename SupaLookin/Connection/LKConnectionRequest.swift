//
//  LKConnectionRequest.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/24.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import LookinShared

final class LKConnectionRequest {

    var type: UInt32 = 0
    var tag: UInt32 = 0
    var receivedDataCount: UInt = 0

    var succBlock: ((LookinConnectionResponseAttachment?) -> Void)?
    var completionBlock: (() -> Void)?
    var failBlock: ((Error) -> Void)?

    /**
     调用 resetTimeoutCount 开始倒计时，如果 timeoutInterval 时间内没有通过 endTimeoutCount 结束倒计时，则 timeoutBlock 会被调用
     */
    /// 超时时间，必须先设置该属性
    var timeoutInterval: TimeInterval = 0
    /// 超时后，该 block 会被调用
    var timeoutBlock: ((LKConnectionRequest) -> Void)?

    private var timeoutTimer: Timer?

    /// 开始或重设倒计时
    func resetTimeoutCount() {
        endTimeoutCount()
        guard timeoutInterval > 0 else {
            assertionFailure("timeoutInterval 为 0")
            return
        }
        // Like performSelector:afterDelay:, the timer runs in the default mode only and keeps the request alive until it fires or is invalidated.
        let timer = Timer(timeInterval: timeoutInterval, repeats: false) { _ in
            MainActor.assumeIsolated {
                self.handleTimeout()
            }
        }
        RunLoop.main.add(timer, forMode: .default)
        timeoutTimer = timer
    }

    /// 结束倒计时。在试图销毁该 LKConnectionRequest 对象前必须先调用该方法结束倒计时
    func endTimeoutCount() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    private func handleTimeout() {
        timeoutTimer = nil
        timeoutBlock?(self)
    }
}
