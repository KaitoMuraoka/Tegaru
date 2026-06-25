//
//  ReactionEvent.swift
//  Tegaru
//
//  Task 1.1: SwiftData データモデル4種と関係・削除規則の定義
//  Requirements: 7.4, 13.1
//

import Foundation
import SwiftData

/// リアクションの種別。アクティビティ一覧（Req 11.2）で統一的に扱う。
enum ReactionKind: String, Codable, CaseIterable {
    case like
    case reply
    case insight
}

/// ペルソナの行為（いいね/返信/気づき）を時刻付きで記録する付帯エンティティ。
/// いいねは `Memo.likedBy` だけでは時刻を持たないため、時系列整列のために本エンティティで記録する
/// （design.md / research.md の設計判断）。
@Model
final class ReactionEvent {
    @Attribute(.unique) var id: UUID
    var kind: ReactionKind
    var createdAt: Date

    /// 行為主体のペルソナ。ペルソナ削除時は関連解除のみ（nullify, 安全側）。
    @Relationship(deleteRule: .nullify)
    var persona: Persona?

    /// 対象メモ。inverse は `Memo.reactionEvents` 側で宣言し、対象メモ削除でイベントごと消滅させる（cascade）。
    var targetMemo: Memo

    /// 返信イベント時の返信メモ本体。メモ削除では参照解除のみ（nullify）。
    @Relationship(deleteRule: .nullify)
    var replyMemo: Memo?

    /// 気づきイベント時の参照先（関連）メモ。メモ削除では参照解除のみ（nullify）。
    @Relationship(deleteRule: .nullify)
    var relatedMemo: Memo?

    /// 気づきイベント時の本文。
    var insightText: String?

    init(
        id: UUID = UUID(),
        kind: ReactionKind,
        createdAt: Date = .now,
        persona: Persona?,
        targetMemo: Memo,
        replyMemo: Memo? = nil,
        relatedMemo: Memo? = nil,
        insightText: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.persona = persona
        self.targetMemo = targetMemo
        self.replyMemo = replyMemo
        self.relatedMemo = relatedMemo
        self.insightText = insightText
    }
}
