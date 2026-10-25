//
//  NSString+LookinClient.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/29.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

extension String {

    /// 返回首字母大写的字符串
    var capitalizedFirstLetter: String? {
        guard let first else {
            return nil
        }
        return first.uppercased() + dropFirst()
    }
}
