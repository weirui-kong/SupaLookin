//
//  NSControl+LookinClient.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/13.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

extension NSControl {

    func height(forWidth width: CGFloat) -> CGFloat {
        sizeThatFits(NSSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    var bestHeight: CGFloat {
        sizeThatFits(.max).height
    }

    var bestWidth: CGFloat {
        sizeThatFits(.max).width
    }

    var bestSize: NSSize {
        sizeThatFits(.max)
    }
}
