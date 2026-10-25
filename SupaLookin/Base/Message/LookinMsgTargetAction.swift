//
//  LookinMsgTargetAction.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/19.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

/// target 和 relatedObject 相等，actionID 相同则认为 equal
final class LookinMsgTargetAction: Equatable {

    weak var target: AnyObject?
    let actionID: String
    weak var relatedObject: AnyObject?
    let action: (AnyObject, LookinMsgActionParams) -> Void

    init(target: AnyObject, actionID: String, relatedObject: AnyObject?, action: @escaping (AnyObject, LookinMsgActionParams) -> Void) {
        self.target = target
        self.actionID = actionID
        self.relatedObject = relatedObject
        self.action = action
    }

    static func == (lhs: LookinMsgTargetAction, rhs: LookinMsgTargetAction) -> Bool {
        lhs === rhs || (lhs.target === rhs.target && lhs.actionID == rhs.actionID && lhs.relatedObject === rhs.relatedObject)
    }
}
