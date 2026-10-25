//
//  NSString+Score.swift
//  SupaLookin
//
//  Created by Nicholas Bruning on 5/12/11.
//  Copyright (c) 2011 Involved Pty Ltd. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

struct NSStringScoreOption: OptionSet {
    let rawValue: UInt

    static let none = NSStringScoreOption(rawValue: 1 << 0)
    static let favorSmallerWords = NSStringScoreOption(rawValue: 1 << 1)
    static let reducedLongStringPenalty = NSStringScoreOption(rawValue: 1 << 2)
}

extension String {

    func score(against otherString: String, fuzziness: CGFloat? = nil, options: NSStringScoreOption = .none) -> CGFloat {
        let invalidCharacterSet = Self.scoreInvalidCharacterSet
        let string = Self.decomposed(self, removing: invalidCharacterSet)
        return score(against: otherString, fuzziness: fuzziness, options: options, invalidCharacterSet: invalidCharacterSet, decomposedString: string)
    }

    private static var scoreInvalidCharacterSet: CharacterSet {
        var set = CharacterSet.lowercaseLetters
        set.formUnion(.uppercaseLetters)
        set.insert(charactersIn: " ")
        return set.inverted
    }

    private static func decomposed(_ string: String, removing invalidCharacterSet: CharacterSet) -> NSString {
        (string as NSString).decomposedStringWithCanonicalMapping.components(separatedBy: invalidCharacterSet).joined() as NSString
    }

    // The arithmetic follows the original NSString+Score exactly, including its UTF-16 indexing and integer division.
    private func score(against anotherString: String, fuzziness: CGFloat?, options: NSStringScoreOption, invalidCharacterSet: CharacterSet, decomposedString: NSString) -> CGFloat {
        var string = decomposedString
        let otherString = Self.decomposed(anotherString, removing: invalidCharacterSet)

        // If the string is equal to the abbreviation, perfect match.
        if string.isEqual(to: otherString as String) {
            return 1
        }

        //if it's not a perfect match and is empty return 0
        if otherString.length == 0 {
            return 0
        }

        var totalCharacterScore: CGFloat = 0
        let otherStringLength = otherString.length
        let stringLength = string.length
        var startOfStringBonus = false
        var fuzzies: CGFloat = 1
        let otherUpper = otherString.uppercased as NSString
        let otherLower = otherString.lowercased as NSString
        let space = (" " as NSString).character(at: 0)

        // Walk through abbreviation and add up scores.
        for index in 0..<otherStringLength {
            var characterScore: CGFloat = 0.1
            var indexInString = NSNotFound
            let range = NSRange(location: index, length: 1)
            let chr = otherString.character(at: index)
            let upperChr = otherUpper.substring(with: range)
            let lowerChr = otherLower.substring(with: range)
            let rangeChrLowercase = string.range(of: lowerChr)
            let rangeChrUppercase = string.range(of: upperChr)

            if rangeChrLowercase.location == NSNotFound && rangeChrUppercase.location == NSNotFound {
                if let fuzziness {
                    fuzzies += 1 - fuzziness
                } else {
                    return 0 // this is an error!
                }
            } else if rangeChrLowercase.location != NSNotFound && rangeChrUppercase.location != NSNotFound {
                indexInString = min(rangeChrLowercase.location, rangeChrUppercase.location)
            } else {
                indexInString = rangeChrLowercase.location != NSNotFound ? rangeChrLowercase.location : rangeChrUppercase.location
            }

            // Same case bonus.
            if indexInString != NSNotFound && string.character(at: indexInString) == chr {
                characterScore += 0.1
            }

            // Consecutive letter & start-of-string bonus
            if indexInString == 0 {
                // Increase the score when matching first character of the remainder of the string
                characterScore += 0.6
                if index == 0 {
                    // If match is the first character of the string
                    // & the first character of abbreviation, add a
                    // start-of-string match bonus.
                    startOfStringBonus = true
                }
            } else if indexInString != NSNotFound {
                // Acronym Bonus
                // Weighing Logic: Typing the first character of an acronym is as if you
                // preceded it with two perfect character matches.
                if string.character(at: indexInString - 1) == space {
                    characterScore += 0.8
                }
            }

            // Left trim the already matched part of the string
            // (forces sequential matching).
            if indexInString != NSNotFound {
                string = string.substring(from: indexInString + 1) as NSString
            }

            totalCharacterScore += characterScore
        }

        if options.contains(.favorSmallerWords) {
            // Weigh smaller words higher
            return totalCharacterScore / CGFloat(stringLength)
        }

        let otherStringScore = totalCharacterScore / CGFloat(otherStringLength)
        var finalScore: CGFloat

        if options.contains(.reducedLongStringPenalty) {
            // Reduce the penalty for longer words
            let percentageOfMatchedString = CGFloat(otherStringLength / stringLength)
            let wordScore = otherStringScore * percentageOfMatchedString
            finalScore = (wordScore + otherStringScore) / 2
        } else {
            finalScore = ((otherStringScore * (CGFloat(otherStringLength) / CGFloat(stringLength))) + otherStringScore) / 2
        }

        finalScore = finalScore / fuzzies

        if startOfStringBonus && finalScore + 0.15 < 1 {
            finalScore += 0.15
        }

        return finalScore
    }
}
