//
//  LKSwiftDemangler.swift
//  SupaLookin
//
//  Created by likai.123 on 2024/1/14.
//  Copyright © 2024 hughkli. All rights reserved.
//
//  Modified by Weirui Kong on 2026/10/25.
//

import Foundation

enum LKSwiftDemangler {

    private static var simpleCache: [String: String] = [:]
    private static var completedCache: [String: String] = [:]

    /// 这里返回的结果会尽可能地短，去除了很多信息
    static func simpleParse(input: String) -> String {
        if let cachedResult = simpleCache[input] {
            return cachedResult
        }
        let result: String
        do {
            let swiftSymbol = try parseMangledSwiftSymbol(input)
            result = swiftSymbol.print(using: [.synthesizeSugarOnTypes, .shortenPartialApply, .shortenThunk, .shortenValueWitness, .shortenArchetype])
        } catch _ {
            result = input
        }
        simpleCache[input] = result
        return result
    }

    /// 这里返回的结果会尽可能地长、包含了 module name 等各种信息
    static func completedParse(input: String) -> String {
        if let cachedResult = completedCache[input] {
            return cachedResult
        }
        let result: String
        do {
            let swiftSymbol = try parseMangledSwiftSymbol(input)
            result = swiftSymbol.print(using: [.displayDebuggerGeneratedModule, .qualifyEntities, .displayExtensionContexts, .displayUnmangledSuffix, .displayModuleNames, .displayGenericSpecializations, .displayProtocolConformances, .displayWhereClauses, .displayEntityTypes, .showPrivateDiscriminators, .showFunctionArgumentTypes])
        } catch _ {
            result = input
        }
        completedCache[input] = result
        return result
    }
}
