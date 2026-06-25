//
//  MemoServiceTests.swift
//  TegaruTests
//
//  Task 2.4: メモ投稿・編集・削除サービス
//  Requirements: 1.1, 1.4, 1.7, 3.3, 3.4, 4.5, 7.1, 16.2, 16.3, 16.4, 16.5, 16.7
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct MemoServiceTests {
    /// 索引呼び出しを記録するスパイ。
    final class SpyIndexer: MemoIndexing {
        var indexed: [UUID] = []
        var removed: [UUID] = []
        func index(_ memo: Memo) { indexed.append(memo.id) }
        func remove(_ id: UUID) { removed.append(id) }
    }

    private func makeContext() throws -> ModelContext {
        try AppModelContainer.makeContainer(inMemory: true).mainContext
    }

    @Test("投稿で新規メモとタグ関連が永続化され、索引登録される")
    func createPersistsMemoAndTags() throws {
        let context = try makeContext()
        let spy = SpyIndexer()
        let service = MemoService(context: context, indexer: spy)

        guard case .success(let id) = service.create(body: "はじめてのメモ #日記") else {
            Issue.record("create は成功すべき"); return
        }
        let memo = context.model(for: id) as! Memo

        #expect(memo.tags.map(\.name) == ["日記"])
        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Tag>()) == 1)
        #expect(spy.indexed.contains(memo.id))
    }

    @Test("画像つき投稿は imageData を保存する")
    func createStoresImage() throws {
        let context = try makeContext()
        let service = MemoService(context: context, indexer: SpyIndexer())
        let bytes = Data([0xAB, 0xCD])

        guard case .success(let id) = service.create(body: "画像メモ", imageData: bytes) else {
            Issue.record("create は成功すべき"); return
        }
        let memo = context.model(for: id) as! Memo
        #expect(memo.imageData == bytes)
    }

    @Test("空白のみの本文は失敗し、何も保存・索引されない")
    func createRejectsEmptyBody() throws {
        let context = try makeContext()
        let spy = SpyIndexer()
        let service = MemoService(context: context, indexer: spy)

        let result = service.create(body: "   \n\t  ")
        #expect(result == .failure(.emptyBody))
        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 0)
        #expect(spy.indexed.isEmpty)
    }

    @Test("返信モードでは parent が設定される")
    func createSetsParent() throws {
        let context = try makeContext()
        let service = MemoService(context: context, indexer: SpyIndexer())

        guard case .success(let parentID) = service.create(body: "親メモ") else {
            Issue.record("create は成功すべき"); return
        }
        let parent = context.model(for: parentID) as! Memo

        guard case .success(let replyID) = service.create(body: "返信", parent: parent) else {
            Issue.record("create は成功すべき"); return
        }
        let reply = context.model(for: replyID) as! Memo

        #expect(reply.parent?.id == parent.id)
        #expect(parent.replies.contains { $0.id == reply.id })
    }

    @Test("編集で updatedAt 設定・createdAt 不変・タグ再同期され AI は起動しない")
    func updateResyncsAndKeepsCreatedAt() throws {
        let context = try makeContext()
        let spy = SpyIndexer()
        let service = MemoService(context: context, indexer: spy)

        guard case .success(let id) = service.create(body: "旧本文 #古") else {
            Issue.record("create は成功すべき"); return
        }
        let memo = context.model(for: id) as! Memo
        let createdAt = memo.createdAt
        #expect(memo.updatedAt == nil)

        guard case .success = service.update(memo, body: "新本文 #新1 #新2", imageData: nil) else {
            Issue.record("update は成功すべき"); return
        }

        #expect(memo.createdAt == createdAt)                       // createdAt 不変
        #expect(memo.updatedAt != nil)                             // updatedAt 設定
        #expect(Set(memo.tags.map(\.name)) == ["新1", "新2"])      // タグ再同期（"古" は外れる）
        #expect(memo.likedBy.isEmpty)                              // AI 非起動
        #expect(memo.replies.isEmpty)                              // AI 非起動
        #expect(spy.indexed.filter { $0 == memo.id }.count == 2)   // create + update で再索引
    }

    @Test("通常メモ削除で関連解除と索引除去が行われる")
    func deleteNormalMemo() throws {
        let context = try makeContext()
        let spy = SpyIndexer()
        let service = MemoService(context: context, indexer: spy)
        let persona = Persona(name: "p", personality: "x", accentColor: "blue")
        context.insert(persona)

        guard case .success(let id) = service.create(body: "消すメモ #t") else {
            Issue.record("create は成功すべき"); return
        }
        let memo = context.model(for: id) as! Memo
        memo.likedBy.append(persona)
        try context.save()
        let memoID = memo.id

        service.delete(memo)

        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Persona>()) == 1)  // ペルソナは残る
        #expect(spy.removed.contains(memoID))
    }

    @Test("親メモ削除で返信が連鎖削除され、全索引が除去される")
    func deleteParentCascades() throws {
        let context = try makeContext()
        let spy = SpyIndexer()
        let service = MemoService(context: context, indexer: spy)

        guard case .success(let pid) = service.create(body: "親") else {
            Issue.record("create は成功すべき"); return
        }
        let parent = context.model(for: pid) as! Memo
        guard case .success(let rid) = service.create(body: "返信", parent: parent) else {
            Issue.record("create は成功すべき"); return
        }
        let reply = context.model(for: rid) as! Memo
        let parentID = parent.id
        let replyID = reply.id

        service.delete(parent)

        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 0)
        #expect(spy.removed.contains(parentID))
        #expect(spy.removed.contains(replyID))
    }
}
