//
//  HashtagHighlighterTests.swift
//  TegaruTests
//
//  Task 3.2: メモ行のハッシュタグ強調表示
//  Requirements: 2.6
//

import Testing
import Foundation
@testable import Tegaru

struct HashtagHighlighterTests {

    @Test("ハッシュタグ範囲を # 込みで返す")
    func tagRangesIncludeHash() {
        let text = "今日は #メモ と #日記"
        let ranges = HashtagHighlighter.tagRanges(in: text)
        let substrings = ranges.map { String(text[$0]) }
        #expect(substrings == ["#メモ", "#日記"])
    }

    @Test("連続したタグも分割して範囲化する")
    func adjacentTags() {
        let text = "#a#b"
        let substrings = HashtagHighlighter.tagRanges(in: text).map { String(text[$0]) }
        #expect(substrings == ["#a", "#b"])
    }

    @Test("タグが無ければ範囲は空")
    func noTags() {
        #expect(HashtagHighlighter.tagRanges(in: "ただの本文").isEmpty)
        #expect(HashtagHighlighter.tagRanges(in: "# だけ").isEmpty)
    }

    @Test("装飾後も元の文字列を保つ")
    func attributedPreservesText() {
        let text = "本文 #タグ あり"
        let attr = HashtagHighlighter.attributedString(for: text)
        #expect(String(attr.characters) == text)
    }

    @Test("タグがあると装飾でランが分割され、無ければ単一ラン")
    func runsSplitOnHashtag() {
        #expect(HashtagHighlighter.attributedString(for: "タグなし").runs.count == 1)
        #expect(HashtagHighlighter.attributedString(for: "前 #tag 後").runs.count > 1)
    }
}
