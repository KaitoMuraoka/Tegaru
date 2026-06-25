//
//  PersonaReactionSchemaTests.swift
//  TegaruTests
//
//  Task 5.2: 構造化出力スキーマの定義
//  Requirements: 9.1, 10.2
//

import Testing
@testable import Tegaru

struct PersonaReactionSchemaTests {

    @Test("ReactionDecision はいいね/返信/返信本文を保持し等価判定できる")
    func reactionDecisionValue() {
        let decision = ReactionDecision(shouldLike: true, shouldReply: true, replyText: "やったね")
        #expect(decision.shouldLike)
        #expect(decision.shouldReply)
        #expect(decision.replyText == "やったね")
        #expect(ReactionDecision.none == ReactionDecision(shouldLike: false, shouldReply: false, replyText: ""))
    }

    @Test("InsightDecision は参照番号と気づき本文を保持する")
    func insightDecisionValue() {
        let insight = InsightDecision(relatedMemoIndex: 2, insightText: "過去のメモとつながっている")
        #expect(insight.relatedMemoIndex == 2)
        #expect(insight.insightText == "過去のメモとつながっている")
    }

    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, *)
    @Test("@Generable 出力は決定値へマッピングできる")
    func mapsGenerableToDecision() {
        let reaction = PersonaReaction(shouldLike: true, shouldReply: false, replyText: "")
        #expect(ReactionDecision(reaction) == ReactionDecision(shouldLike: true, shouldReply: false, replyText: ""))

        let insight = PersonaInsight(relatedMemoIndex: 1, insightText: "気づき")
        #expect(InsightDecision(insight) == InsightDecision(relatedMemoIndex: 1, insightText: "気づき"))
    }
    #endif
}
