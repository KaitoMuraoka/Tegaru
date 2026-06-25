//
//  Persona.swift
//  Tegaru
//
//  Task 1.1: SwiftData データモデル4種と関係・削除規則の定義
//  Requirements: 7.4, 13.1
//

import Foundation
import SwiftData

/// AI ペルソナ。性格指示文・表示名・識別色を持ち、いいね/返信の主体となる。
@Model
final class Persona {
    @Attribute(.unique) var id: UUID
    var name: String
    /// 独立セッションの instructions に使う性格指示文（Req 8.4）。
    var personality: String
    /// 表示用アクセントカラー名（Shared/AccentColor でマッピング）。
    var accentColor: String

    /// このペルソナが書いた返信メモ。メモ削除では関連解除のみ（nullify）。
    @Relationship(deleteRule: .nullify, inverse: \Memo.author)
    var authoredMemos: [Memo]

    /// このペルソナがいいねしたメモ（多対多）。メモ削除では関連解除のみ（nullify）。
    @Relationship(deleteRule: .nullify, inverse: \Memo.likedBy)
    var likedMemos: [Memo]

    init(
        id: UUID = UUID(),
        name: String,
        personality: String,
        accentColor: String
    ) {
        self.id = id
        self.name = name
        self.personality = personality
        self.accentColor = accentColor
        self.authoredMemos = []
        self.likedMemos = []
    }
}
