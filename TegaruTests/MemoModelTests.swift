//
//  MemoModelTests.swift
//  TegaruTests
//
//  Task 1.1: SwiftData データモデル4種と関係・削除規則の定義
//  Requirements: 7.4, 13.1
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct MemoModelTests {

    /// 端末外同期・ネットワークを持たない、メモリ内のみの ModelContainer を作る（Req 13.1）。
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Memo.self, Persona.self, Tag.self, ReactionEvent.self,
            configurations: config
        )
    }

    @Test("4モデルがコンパイル・永続化でき、取得できる")
    func persistsAllFourModels() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let persona = Persona(name: "共感ロイド", personality: "やさしく共感する", accentColor: "blue")
        let tag = Tag(name: "メモ")
        let memo = Memo(body: "はじめてのメモ #メモ")
        memo.tags.append(tag)
        memo.likedBy.append(persona)

        context.insert(persona)
        context.insert(tag)
        context.insert(memo)
        let event = ReactionEvent(kind: .like, persona: persona, targetMemo: memo)
        context.insert(event)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Persona>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Tag>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ReactionEvent>()) == 1)
    }

    @Test("画像は外部保存属性として保持できる（Req 7.4）")
    func storesImageData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let bytes = Data([0x01, 0x02, 0x03, 0x04])
        let memo = Memo(body: "画像つきメモ", imageData: bytes)
        context.insert(memo)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Memo>())
        #expect(fetched.first?.imageData == bytes)
    }

    @Test("親メモ削除で返信が連鎖削除される（cascade）")
    func cascadeDeletesReplies() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let persona = Persona(name: "ツッコミ", personality: "鋭くツッコむ", accentColor: "red")
        let parent = Memo(body: "親メモ")
        context.insert(persona)
        context.insert(parent)
        let reply = Memo(body: "ペルソナの返信", author: persona, parent: parent)
        context.insert(reply)
        try context.save()

        #expect(parent.replies.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 2)

        context.delete(parent)
        try context.save()

        // 親メモと返信の両方が消える
        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 0)
        // ペルソナは削除されない（nullify）
        #expect(try context.fetchCount(FetchDescriptor<Persona>()) == 1)
    }

    @Test("メモ削除でいいね・タグ関連が解除され、ペルソナ/タグは残る（nullify）")
    func nullifiesLikeAndTagRelations() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let persona = Persona(name: "専門家", personality: "理屈っぽい", accentColor: "green")
        let tag = Tag(name: "技術")
        let memo = Memo(body: "本文 #技術")
        memo.likedBy.append(persona)
        memo.tags.append(tag)
        context.insert(persona)
        context.insert(tag)
        context.insert(memo)
        try context.save()

        #expect(persona.likedMemos.count == 1)
        #expect(tag.memos.count == 1)

        context.delete(memo)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 0)
        // いいね・タグの関連は解除されるが、ペルソナとタグ自体は残る
        #expect(try context.fetchCount(FetchDescriptor<Persona>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Tag>()) == 1)
        #expect(persona.likedMemos.isEmpty)
        #expect(tag.memos.isEmpty)
    }

    @Test("対象メモ削除でリアクションイベントも連鎖削除される（targetMemo cascade）")
    func cascadeDeletesReactionEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let persona = Persona(name: "共感", personality: "やさしい", accentColor: "blue")
        let memo = Memo(body: "対象メモ")
        context.insert(persona)
        context.insert(memo)
        let event = ReactionEvent(kind: .like, persona: persona, targetMemo: memo)
        context.insert(event)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<ReactionEvent>()) == 1)

        context.delete(memo)
        try context.save()

        // 対象メモへのイベントは消滅、ペルソナは残る（dangling 参照を作らない）
        #expect(try context.fetchCount(FetchDescriptor<ReactionEvent>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Persona>()) == 1)
    }

    @Test("createdAt は不変で updatedAt は編集時のみ設定される")
    func timestampsBehaveAsDesigned() throws {
        let created = Date(timeIntervalSince1970: 1_000)
        let memo = Memo(body: "本文", createdAt: created)

        #expect(memo.createdAt == created)
        #expect(memo.updatedAt == nil)

        let edited = Date(timeIntervalSince1970: 2_000)
        memo.updatedAt = edited

        #expect(memo.createdAt == created)   // createdAt は不変
        #expect(memo.updatedAt == edited)
    }
}
