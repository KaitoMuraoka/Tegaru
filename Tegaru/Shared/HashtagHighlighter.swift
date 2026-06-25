//
//  HashtagHighlighter.swift
//  Tegaru
//
//  Task 3.2: メモ行のハッシュタグ強調表示
//  Requirements: 2.6
//

import Foundation
import SwiftUI

/// 本文中の `#xxx` をリンク風に強調するためのユーティリティ。
enum HashtagHighlighter {
    private static let pattern = "#[\\p{L}\\p{N}_]+"

    /// 本文中のハッシュタグ範囲（先頭 `#` を含む）を出現順に返す。
    static func tagRanges(in text: String) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { Range($0.range, in: text) }
    }

    /// ハッシュタグ部分に色を付けた `AttributedString` を返す。
    static func attributedString(for text: String, color: Color = .accentColor) -> AttributedString {
        var attributed = AttributedString(text)
        for range in tagRanges(in: text) {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let length = text.distance(from: range.lowerBound, to: range.upperBound)
            let lower = attributed.index(attributed.startIndex, offsetByCharacters: start)
            let upper = attributed.index(lower, offsetByCharacters: length)
            attributed[lower..<upper].foregroundColor = color
        }
        return attributed
    }
}
