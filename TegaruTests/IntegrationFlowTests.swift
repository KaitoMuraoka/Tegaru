//
//  IntegrationFlowTests.swift
//  TegaruTests
//
//  Task 7.4: 統合テスト（削除連鎖・AIリアクション適用・編集再索引）
//  Requirements: 3.4, 9.1, 9.2, 9.3, 11.2, 16.5, 16.7
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct IntegrationFlowTests {

    // MARK: テスト用ダブル

    final class SpyIndexer: MemoIndexing {
        var indexed: [UUID] = []
        var removed: [UUID] = []
        func index(_ memo: Memo) { indexed.append(memo.id) }
        func remove(_ id: UUID) { removed.append(id) }
    }

    struct AlwaysReactGenerator: PersonaReactionGenerating {
        let reply: String
        let insightText: String
        func reaction(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> ReactionDecision {
            ReactionDecision(shouldLike: true, shouldReply: !reply.isEmpty, replyText: reply)
        }
        func insight(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> InsightDecision? {
            InsightDecision(relatedMemoIndex: 0, insightText: insightText)
        }
    }

    private func makeContainer() throws -> ModelContainer {
        try AppModelContainer.makeContainer(inMemory: true)
    }

    private func date(_ t: TimeInterval) -> Date { Date(timeIntervalSince1970: t) }

    // MARK: 7.4-a 親メモ削除の連鎖とイベント/索引整合（孤児参照なし）

    @Test("親メモ削除で返信・対応イベント・索引が一貫して除去される")
    func cascadeDeleteKeepsIntegrity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let spy = SpyIndexer()
        let service = MemoService(context: context, indexer: spy)

        let persona = Persona(name: "p", personality: "x", accentColor: "blue")
        context.insert(persona)

        guard case .success(let pid) = service.create(body: "親 #t") else { Issue.record("x"); return }
        let parent = context.model(for: pid) as! Memo
        guard case .success(let rid) = service.create(body: "返信", parent: parent) else { Issue.record("x"); return }
        let reply = context.model(for: rid) as! Memo

        // 親宛のいいね・返信イベントと、返信宛のいいねイベントを記録
        context.insert(ReactionEvent(kind: .like, persona: persona, targetMemo: parent))
        context.insert(ReactionEvent(kind: .reply, persona: persona, targetMemo: parent, replyMemo: reply))
        context.insert(ReactionEvent(kind: .like, persona: persona, targetMemo: reply))
        try context.save()
        let parentID = parent.id
        let replyID = reply.id

        service.delete(parent)

        // メモ・イベントは全消滅、ペルソナは残る（dangling 参照なし）
        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ReactionEvent>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Persona>()) == 1)
        // Spotlight 索引は親・返信ともに除去
        #expect(spy.removed.contains(parentID))
        #expect(spy.removed.contains(replyID))
    }

    // MARK: 7.4-b 投稿 → リアクション適用 → アクティビティ反映

    @Test("投稿後にいいね/返信/気づきが適用されアクティビティに反映される")
    func postThenReactionThenActivity() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = MemoService(context: context, indexer: SpyIndexer())

        context.insert(Persona(name: "p1", personality: "x", accentColor: "blue"))
        context.insert(Persona(name: "p2", personality: "y", accentColor: "red"))
        let tag = Tag(name: "A"); context.insert(tag)
        let past = Memo(body: "過去 #A", createdAt: date(1)); past.tags = [tag]
        context.insert(past)
        try context.save()

        guard case .success(let id) = service.create(body: "対象 #A") else { Issue.record("x"); return }

        let engine = PersonaReactionEngine(modelContainer: container)
        await engine.configure(
            generator: AlwaysReactGenerator(reply: "いいね！", insightText: "つながりがある"),
            relatedFinder: TagOverlapFinder(),
            reactionDelay: .zero
        )
        await engine.start(memoID: id)

        let verify = ModelContext(container)
        let events = try verify.fetch(ReactionEvent.activityDescriptor)
        #expect(events.filter { $0.kind == .like }.count == 2)
        #expect(events.filter { $0.kind == .reply }.count == 2)
        #expect(events.filter { $0.kind == .insight }.count == 1)

        // アクティビティは createdAt 降順（非増加）
        let times = events.map(\.createdAt)
        #expect(zip(times, times.dropFirst()).allSatisfy { $0 >= $1 })

        // 対象メモにいいねが2件付く
        let target = verify.model(for: id) as! Memo
        #expect(target.likedBy.count == 2)
    }

    // MARK: 7.4-c 編集後の再索引・タグ再同期・既存反応維持

    @Test("編集で再索引・タグ再同期されても既存のいいね/返信は維持される")
    func editReindexesButKeepsReactions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let spy = SpyIndexer()
        let service = MemoService(context: context, indexer: spy)

        let persona = Persona(name: "p", personality: "x", accentColor: "blue")
        context.insert(persona)

        guard case .success(let id) = service.create(body: "旧本文 #古") else { Issue.record("x"); return }
        let memo = context.model(for: id) as! Memo
        let createdAt = memo.createdAt

        // 既存の AI 反応を再現（いいね + 返信メモ + イベント）
        memo.likedBy.append(persona)
        let reply = Memo(body: "既存返信", author: persona, parent: memo)
        context.insert(reply)
        context.insert(ReactionEvent(kind: .like, persona: persona, targetMemo: memo))
        try context.save()
        let indexCountBefore = spy.indexed.filter { $0 == memo.id }.count

        guard case .success = service.update(memo, body: "新本文 #新", imageData: nil) else { Issue.record("x"); return }

        // 再索引・タグ再同期・updatedAt 設定・createdAt 不変
        #expect(spy.indexed.filter { $0 == memo.id }.count == indexCountBefore + 1)
        #expect(Set(memo.tags.map(\.name)) == ["新"])
        #expect(memo.updatedAt != nil)
        #expect(memo.createdAt == createdAt)

        // 既存反応は維持（AI 再生成しない, Req 16.7）
        #expect(memo.likedBy.contains { $0.id == persona.id })
        #expect(memo.replies.contains { $0.id == reply.id })
        #expect(try context.fetchCount(FetchDescriptor<ReactionEvent>()) == 1)
    }
}
