//
//  MemoQueriesTests.swift
//  TegaruTests
//
//  Task 3.2 / 3.3 / 3.4: タイムライン・スレッド・検索のデータストア側クエリ
//  Requirements: 2.1, 2.2, 5.1, 5.3, 5.4, 6.1, 6.2, 6.3, 14.2
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct MemoQueriesTests {
    private func makeContext() throws -> ModelContext {
        try AppModelContainer.makeContainer(inMemory: true).mainContext
    }

    private func date(_ t: TimeInterval) -> Date { Date(timeIntervalSince1970: t) }

    @Test("タイムラインはルートメモ（作者なし・親なし）のみを降順で返す")
    func timelineRootsDescending() throws {
        let context = try makeContext()
        let persona = Persona(name: "p", personality: "x", accentColor: "blue")
        context.insert(persona)

        let old = Memo(body: "古い", createdAt: date(100))
        let recent = Memo(body: "新しい", createdAt: date(200))
        context.insert(old)
        context.insert(recent)
        context.insert(Memo(body: "返信", createdAt: date(300), parent: old))
        context.insert(Memo(body: "ペルソナ投稿", createdAt: date(400), author: persona))
        try context.save()

        let result = try context.fetch(Memo.timelineDescriptor)
        #expect(result.map(\.body) == ["新しい", "古い"])
    }

    @Test("本文検索は部分一致したメモを降順で返す")
    func searchByBodyDescending() throws {
        let context = try makeContext()
        context.insert(Memo(body: "りんごメモ", createdAt: date(100)))
        context.insert(Memo(body: "りんごジュース", createdAt: date(200)))
        context.insert(Memo(body: "みかん", createdAt: date(300)))
        try context.save()

        let result = try context.fetch(Memo.searchByBody("りんご"))
        #expect(result.map(\.body) == ["りんごジュース", "りんごメモ"])
    }

    @Test("タグ絞り込みは該当タグを持つメモのみを降順で返す")
    func searchByTagDescending() throws {
        let context = try makeContext()
        let tag = Tag(name: "日記")
        context.insert(tag)

        let a = Memo(body: "A #日記", createdAt: date(100)); a.tags = [tag]
        let b = Memo(body: "B", createdAt: date(200))
        let c = Memo(body: "C #日記", createdAt: date(300)); c.tags = [tag]
        [a, b, c].forEach { context.insert($0) }
        try context.save()

        let result = try context.fetch(Memo.searchByTag("日記"))
        #expect(result.map(\.body) == ["C #日記", "A #日記"])
    }

    @Test("スレッドの返信は createdAt の昇順で並ぶ")
    func repliesAscending() throws {
        let context = try makeContext()
        let parent = Memo(body: "親", createdAt: date(0))
        context.insert(parent)
        context.insert(Memo(body: "後", createdAt: date(200), parent: parent))
        context.insert(Memo(body: "先", createdAt: date(100), parent: parent))
        try context.save()

        #expect(Memo.sortedReplies(of: parent).map(\.body) == ["先", "後"])
    }

    @Test("author の有無でペルソナ返信を判別する")
    func personaReplyFlag() {
        let mine = Memo(body: "自分のメモ")
        let persona = Persona(name: "p", personality: "x", accentColor: "red")
        let personaReply = Memo(body: "ペルソナ返信", author: persona, parent: mine)

        #expect(mine.isPersonaReply == false)
        #expect(personaReply.isPersonaReply == true)
    }
}
