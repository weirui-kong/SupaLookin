//
//  LookinObject+LookinClient.swift
//  SupaLookin
//
//  Created by likai.123 on 2024/1/14.
//  Copyright © 2024 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import LookinShared

extension LookinObject {

    /// 这里返回的类名已经被 demangle 过，但是【有 module 前缀】
    var completedDemangledClassName: String {
        LKSwiftDemangler.completedParse(input: rawClassName() ?? "")
    }

    /// 这里返回的类名已经被 demangle 过，并且【没有 module 前缀】
    var simpleDemangledClassName: String {
        let name = LKSwiftDemangler.simpleParse(input: rawClassName() ?? "")
        // 理论上可能有 bad case，比如 xx<aaa.bbb>，期望拿到 xx 但是这里会拿到 bbb……不过似乎没发现过，所以先这样简单处理吧
        return name.components(separatedBy: ".").last ?? name
    }
}
