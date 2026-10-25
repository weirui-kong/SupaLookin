//
//  LKDashboardAttributeClassView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/14.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeClassView: LKDashboardAttributeStringArrayView {

    override func stringList(withAttribute attribute: LookinAttribute?) -> [String] {
        let lists = attribute?.value as? [[String]] ?? []
        return lists.map { rawClassList in
            rawClassList.map { LKSwiftDemangler.completedParse(input: $0) }.joined(separator: "\n")
        }
    }
}
