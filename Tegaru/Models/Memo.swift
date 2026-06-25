//
//  Memo.swift
//  Tegaru
//
//  Task 1.1: SwiftData データモデル4種と関係・削除規則の定義
//  Requirements: 7.4, 13.1
//

import Foundation
import SwiftData

/// 投稿・返信を表す集約ルート。`author == nil && parent == nil` がルート（自分の）投稿、
/// `author != nil && parent != nil` がペルソナによる返信（design.md Domain Model）。
@Model
final class Memo {
    @Attribute(.unique) var id: UUID
    var body: String
    /// 生成後は不変（Req 16.4）。
    var createdAt: Date
    /// 編集時のみ設定（Req 16.3）。未編集なら nil。
    var updatedAt: Date?

    /// 画像は外部ファイルへ保存する（Req 7.4）。
    @Attribute(.externalStorage) var imageData: Data?

    /// 作者。nil は自分の投稿。inverse は `Persona.authoredMemos` 側で宣言（nullify）。
    var author: Persona?

    /// 親メモ。inverse は `replies` 側で宣言。
    var parent: Memo?

    /// 返信群。親メモ削除で連鎖削除する（Req 3.4）。
    @Relationship(deleteRule: .cascade, inverse: \Memo.parent)
    var replies: [Memo]

    /// いいねしたペルソナ（多対多）。inverse は `Persona.likedMemos` 側で宣言（nullify）。
    var likedBy: [Persona]

    /// 紐づくタグ（多対多）。inverse は `Tag.memos` 側で宣言（nullify）。
    var tags: [Tag]

    /// このメモを対象とするリアクションイベント。対象メモ削除でイベントも消滅させるため、
    /// `ReactionEvent.targetMemo` の inverse をここで明示し cascade を付与する（design.md / Req 11.2 孤児防止）。
    @Relationship(deleteRule: .cascade, inverse: \ReactionEvent.targetMemo)
    var reactionEvents: [ReactionEvent]

    init(
        id: UUID = UUID(),
        body: String,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        imageData: Data? = nil,
        author: Persona? = nil,
        parent: Memo? = nil
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageData = imageData
        self.author = author
        self.parent = parent
        self.replies = []
        self.likedBy = []
        self.tags = []
        self.reactionEvents = []
    }
}
