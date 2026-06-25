//
//  PersonaReaction.swift
//  Tegaru
//
//  Task 5.2: 構造化出力スキーマの定義
//  Requirements: 9.1, 10.2
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// いいね/返信の判定（ペルソナごとに1回生成, Req 9.1）。
@available(iOS 26, macOS 26, *)
@Generable
struct PersonaReaction {
    @Guide(description: "この投稿にいいねするか") let shouldLike: Bool
    @Guide(description: "返信するか") let shouldReply: Bool
    @Guide(description: "返信する場合の短いカジュアルな本文。しない場合は空") let replyText: String
}

/// 関連メモがある場合のみ、代表ペルソナが1回だけ生成する「気づき」(Req 10.2, 10.5)。
@available(iOS 26, macOS 26, *)
@Generable
struct PersonaInsight {
    @Guide(description: "提示された関連メモのうち、最も関連が強いものの番号(0始まり)") let relatedMemoIndex: Int
    @Guide(description: "過去メモとのつながりを述べる短い気づき。なければ空") let insightText: String
}
#endif

/// 生成系から切り離した、エンジンが扱う決定値（`@Generable` 非依存・Sendable）。
struct ReactionDecision: Equatable, Sendable {
    var shouldLike: Bool
    var shouldReply: Bool
    var replyText: String

    /// 反応なし。
    static let none = ReactionDecision(shouldLike: false, shouldReply: false, replyText: "")
}

struct InsightDecision: Equatable, Sendable {
    var relatedMemoIndex: Int
    var insightText: String
}

#if canImport(FoundationModels)
@available(iOS 26, macOS 26, *)
extension ReactionDecision {
    init(_ reaction: PersonaReaction) {
        self.init(shouldLike: reaction.shouldLike, shouldReply: reaction.shouldReply, replyText: reaction.replyText)
    }
}

@available(iOS 26, macOS 26, *)
extension InsightDecision {
    init(_ insight: PersonaInsight) {
        self.init(relatedMemoIndex: insight.relatedMemoIndex, insightText: insight.insightText)
    }
}
#endif
