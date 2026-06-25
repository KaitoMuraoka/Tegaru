//
//  PersonaReactionEngineTests.swift
//  TegaruTests
//
//  Task 5.4: ペルソナリアクションエンジン
//  Requirements: 8.4, 9.1, 9.2, 9.3, 9.5, 9.6, 10.2, 10.5, 11.2, 15.5
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct PersonaReactionEngineTests {

    // MARK: フェイクジェネレータ

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

    struct EmptyReplyGenerator: PersonaReactionGenerating {
        func reaction(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> ReactionDecision {
            ReactionDecision(shouldLike: false, shouldReply: true, replyText: "   ")
        }
        func insight(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> InsightDecision? { nil }
    }

    struct ThrowingGenerator: PersonaReactionGenerating {
        struct Failure: Error {}
        func reaction(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> ReactionDecision { throw Failure() }
        func insight(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> InsightDecision? { throw Failure() }
    }

    private func makeContainer() throws -> ModelContainer {
        try AppModelContainer.makeContainer(inMemory: true)
    }

    private func date(_ t: TimeInterval) -> Date { Date(timeIntervalSince1970: t) }

    @Test("全ペルソナのいいね・返信と代表の気づきが適用・記録される")
    func appliesLikesRepliesAndInsight() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Persona(name: "p1", personality: "x", accentColor: "blue"))
        context.insert(Persona(name: "p2", personality: "y", accentColor: "red"))

        let tag = Tag(name: "A"); context.insert(tag)
        let past = Memo(body: "過去 #A", createdAt: date(1)); past.tags = [tag]
        let target = Memo(body: "対象 #A", createdAt: date(2)); target.tags = [tag]
        context.insert(past)
        context.insert(target)
        try context.save()
        let memoID = target.persistentModelID

        let engine = PersonaReactionEngine(modelContainer: container)
        await engine.configure(
            generator: AlwaysReactGenerator(reply: "いいね！", insightText: "つながりがある"),
            relatedFinder: TagOverlapFinder(),
            reactionDelay: .zero
        )
        await engine.start(memoID: memoID)

        let verify = ModelContext(container)
        let events = try verify.fetch(FetchDescriptor<ReactionEvent>())
        #expect(events.filter { $0.kind == .like }.count == 2)
        #expect(events.filter { $0.kind == .reply }.count == 2)
        #expect(events.filter { $0.kind == .insight }.count == 1)
        // target + past + 返信2件
        #expect(try verify.fetchCount(FetchDescriptor<Memo>()) == 4)
    }

    @Test("無反応ジェネレータでは何も適用されない")
    func noReactionApplies() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Persona(name: "p1", personality: "x", accentColor: "blue"))
        let target = Memo(body: "対象")
        context.insert(target)
        try context.save()
        let id = target.persistentModelID

        let engine = PersonaReactionEngine(modelContainer: container)
        await engine.configure(generator: NullReactionGenerator(), relatedFinder: TagOverlapFinder(), reactionDelay: .zero)
        await engine.start(memoID: id)

        let verify = ModelContext(container)
        #expect(try verify.fetchCount(FetchDescriptor<ReactionEvent>()) == 0)
        #expect(try verify.fetchCount(FetchDescriptor<Memo>()) == 1)
    }

    @Test("返信本文が空なら返信メモは作られない")
    func emptyReplyCreatesNoReply() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Persona(name: "p1", personality: "x", accentColor: "blue"))
        let target = Memo(body: "対象")   // タグなし → 気づきも無し
        context.insert(target)
        try context.save()
        let id = target.persistentModelID

        let engine = PersonaReactionEngine(modelContainer: container)
        await engine.configure(generator: EmptyReplyGenerator(), relatedFinder: TagOverlapFinder(), reactionDelay: .zero)
        await engine.start(memoID: id)

        let verify = ModelContext(container)
        #expect(try verify.fetchCount(FetchDescriptor<ReactionEvent>()) == 0)
        #expect(try verify.fetchCount(FetchDescriptor<Memo>()) == 1)
    }

    @Test("関連メモが無ければ気づきは生成されない")
    func noRelatedNoInsight() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Persona(name: "p1", personality: "x", accentColor: "blue"))
        let target = Memo(body: "対象")   // タグなし → related 空
        context.insert(target)
        try context.save()
        let id = target.persistentModelID

        let engine = PersonaReactionEngine(modelContainer: container)
        await engine.configure(
            generator: AlwaysReactGenerator(reply: "やあ", insightText: "気づき"),
            relatedFinder: TagOverlapFinder(),
            reactionDelay: .zero
        )
        await engine.start(memoID: id)

        let verify = ModelContext(container)
        let events = try verify.fetch(FetchDescriptor<ReactionEvent>())
        #expect(events.filter { $0.kind == .insight }.isEmpty)
        #expect(events.filter { $0.kind == .like }.count == 1)
        #expect(events.filter { $0.kind == .reply }.count == 1)
    }

    @Test("生成失敗時は当該ペルソナをスキップし、クラッシュせず記録もしない")
    func throwingGeneratorSkips() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Persona(name: "p1", personality: "x", accentColor: "blue"))
        let target = Memo(body: "対象")
        context.insert(target)
        try context.save()
        let id = target.persistentModelID

        let engine = PersonaReactionEngine(modelContainer: container)
        await engine.configure(generator: ThrowingGenerator(), relatedFinder: TagOverlapFinder(), reactionDelay: .zero)
        await engine.start(memoID: id)

        let verify = ModelContext(container)
        #expect(try verify.fetchCount(FetchDescriptor<ReactionEvent>()) == 0)
        #expect(try verify.fetchCount(FetchDescriptor<Memo>()) == 1)
    }
}
