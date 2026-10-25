//
//  LKDashboardSearchMethodsDataSource.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/6.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import LookinShared

final class LKDashboardSearchMethodsDataSource {

    /**
     [
         "UIView": ["layoutSubviews", "addSubview:", ...],
         "UIViewController": ["viewDidAppear:", ...],
         ...
     ]
     */
    private var classesToSelsDict: [String: [String]] = [:]

    func fetchNonArgMethodsList(withClass className: String?) async throws -> [String]? {
        guard let className, !className.isEmpty else {
            throw LookinError.inner
        }
        guard let inspectingApp = LKAppsManager.sharedInstance.inspectingApp else {
            throw LookinError.noConnect
        }
        if let cached = classesToSelsDict[className] {
            return cached
        }

        let sels = try await inspectingApp.fetchSelectorNames(withClass: className, hasArg: false)
        classesToSelsDict[className] = sels
        return sels
    }

    func clearAllCache() {
        classesToSelsDict.removeAll()
    }
}
