//
//  LKDanceUIAttrMaker.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/12/21.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import LookinShared

enum LKDanceUIAttrMaker {

    /// 给 item 的属性列表里填充上“跳转 DanceUI 文件”相关的信息
    static func makeDanceUIJumpAttribute(_ item: LookinDisplayItem, danceSource source: String) {
        guard let className = getClass(fromSource: source) else {
            return
        }

        let alreadyHas = (item.attributesGroupList ?? []).contains { $0.identifier == LookinAttrGroup_Class }
        if alreadyHas {
            return
        }
        let attr = LookinAttribute()
        attr.identifier = LookinAttr_Class_Class_Class
        attr.attrType = .customObj
        attr.value = [[className]]

        let sec = LookinAttributesSection()
        sec.identifier = LookinAttrSec_Class_Class
        sec.attributes = [attr]

        let group = LookinAttributesGroup()
        group.identifier = LookinAttrGroup_Class
        group.attrSections = [sec]

        item.attributesGroupList = (item.attributesGroupList ?? []) + [group]
    }

    private static func getClass(fromSource json: String) -> String? {
        guard let jsonData = json.data(using: .utf8) else {
            assertionFailure()
            return nil
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: jsonData)
        } catch {
            assertionFailure()
            return nil
        }
        guard let dict = object as? [String: Any] else {
            assertionFailure()
            return nil
        }
        guard let type = dict["type"] as? String else {
            assertionFailure()
            return nil
        }
        return type
    }
}
