//
//  VersionComparison.swift
//  Pearcleaner
//

import Foundation

struct Version: Hashable, Comparable {
    let versionNumber: String?
    let buildNumber: String?

    var isEmpty: Bool {
        comparisonValue?.isEmpty ?? true
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        compare(lhs.comparisonValue, rhs.comparisonValue) == .orderedAscending
    }

    private var comparisonValue: String? {
        if let buildNumber, buildNumber != versionNumber {
            return buildNumber
        }
        return versionNumber
    }

    private enum Token: Equatable {
        case number(String)
        case text(String)
    }

    private static func compare(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        let left = tokens(from: lhs)
        let right = tokens(from: rhs)
        let sharedCount = min(left.count, right.count)

        for index in 0..<sharedCount {
            let result = compare(left[index], right[index])
            if result != .orderedSame {
                return result
            }
        }

        return compareRemainder(
            left.count > sharedCount ? Array(left[sharedCount...]) : [],
            right.count > sharedCount ? Array(right[sharedCount...]) : []
        )
    }

    private static func tokens(from value: String?) -> [Token] {
        guard let value else { return [] }
        var tokens: [Token] = []
        var current = ""
        var currentIsNumber: Bool?

        func flush() {
            guard !current.isEmpty else { return }
            if currentIsNumber == true {
                let normalized = current.drop(while: { $0 == "0" })
                tokens.append(.number(normalized.isEmpty ? "0" : String(normalized)))
            } else {
                tokens.append(.text(current.lowercased()))
            }
            current = ""
        }

        for character in value {
            guard character.isLetter || character.isNumber else {
                flush()
                currentIsNumber = nil
                continue
            }

            let isNumber = character.isNumber
            if let currentIsNumber, currentIsNumber != isNumber {
                flush()
            }
            currentIsNumber = isNumber
            current.append(character)
        }
        flush()
        return tokens
    }

    private static func compare(_ lhs: Token, _ rhs: Token) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (.number(left), .number(right)):
            if left.count != right.count {
                return left.count < right.count ? .orderedAscending : .orderedDescending
            }
            return left.compare(right)
        case let (.text(left), .text(right)):
            return left.compare(right)
        case (.number, .text):
            return .orderedDescending
        case (.text, .number):
            return .orderedAscending
        }
    }

    private static func compareRemainder(_ lhs: [Token], _ rhs: [Token]) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        if lhs.isEmpty {
            return rhs.allSatisfy(isZero) ? .orderedSame : remainderResult(rhs, reversed: true)
        }
        if rhs.isEmpty {
            return lhs.allSatisfy(isZero) ? .orderedSame : remainderResult(lhs, reversed: false)
        }
        return .orderedSame
    }

    private static func isZero(_ token: Token) -> Bool {
        token == .number("0")
    }

    private static func remainderResult(_ tokens: [Token], reversed: Bool) -> ComparisonResult {
        let containsText = tokens.contains { token in
            if case .text = token { return true }
            return false
        }
        let result: ComparisonResult = containsText ? .orderedAscending : .orderedDescending
        if !reversed { return result }
        return result == .orderedAscending ? .orderedDescending : .orderedAscending
    }
}
