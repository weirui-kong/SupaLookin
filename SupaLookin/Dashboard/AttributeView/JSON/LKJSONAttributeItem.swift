//
//  LKJSONAttributeItem.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/12/4.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

final class LKJSONAttributeItem {

    var titleText: String?
    var desc: String?
    var expanded = true
    var indentation = 0
    var subItems: [LKJSONAttributeItem]? = []

    func flatItems() -> [LKJSONAttributeItem] {
        var array = [self]

        if expanded {
            for obj in subItems ?? [] {
                obj.indentation = indentation + 1
                array.append(contentsOf: obj.flatItems())
            }
        }

        return array
    }

    /// LKJSONAttributeContentView 和 LKJSONAttributeViewController 共用的解析逻辑
    static func items(fromArray rawArray: Any?) -> [LKJSONAttributeItem]? {
        guard let rawArray = rawArray as? [Any] else {
            return nil
        }
        var resultArray: [LKJSONAttributeItem] = []

        for element in rawArray {
            guard let dict = element as? [String: Any] else {
                continue
            }
            let item = LKJSONAttributeItem()
            item.titleText = dict["title"] as? String
            item.desc = dict["desc"] as? String
            item.expanded = true
            item.subItems = items(fromArray: dict["details"])

            resultArray.append(item)
        }

        return resultArray
    }

    static func rootItems(fromJSON json: String) -> [LKJSONAttributeItem]? {
        guard let jsonData = json.data(using: .utf8) else {
            return nil
        }
        let array: Any
        do {
            array = try JSONSerialization.jsonObject(with: jsonData)
        } catch {
            NSLog("转换失败: %@", String(describing: error))
            assertionFailure()
            return nil
        }
        guard array is [Any] else {
            return nil
        }
        return items(fromArray: array)
    }
}
