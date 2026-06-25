//
//  HashtagExtractorTests.swift
//  TegaruTests
//
//  Task 2.1: ハッシュタグ抽出（純関数）
//  Requirements: 4.1, 4.2, 4.6
//

import Testing
@testable import Tegaru

struct HashtagExtractorTests {
    private let sut = HashtagExtractor()

    @Test("日本語を含むタグを抽出する")
    func extractsJapanese() {
        #expect(sut.extract(from: "今日の #メモ を書く") == ["メモ"])
    }

    @Test("英数字・アンダースコアのタグを抽出する")
    func extractsAlphanumericUnderscore() {
        #expect(sut.extract(from: "完了 #test_1") == ["test_1"])
    }

    @Test("複数タグを出現順で抽出し重複を除外する")
    func extractsMultipleAndDeduplicates() {
        #expect(sut.extract(from: "#a #b と #a それから #c") == ["a", "b", "c"])
    }

    @Test("連続したタグも分割して抽出する")
    func splitsAdjacentTags() {
        #expect(sut.extract(from: "#tag1#tag2") == ["tag1", "tag2"])
    }

    @Test("# 単体は無効でタグにならない")
    func ignoresLoneHash() {
        #expect(sut.extract(from: "これは # だけ").isEmpty)
        #expect(sut.extract(from: "#").isEmpty)
    }

    @Test("タグが無ければ空配列を返す")
    func returnsEmptyWhenNoTags() {
        #expect(sut.extract(from: "ただの本文です").isEmpty)
    }
}
