//
//  Tag.swift
//  Tegaru
//
//  Task 1.1: SwiftData データモデル4種と関係・削除規則の定義
//  Requirements: 7.4, 13.1
//

import Foundation
import SwiftData

/// ハッシュタグ。`name` は先頭 `#` を含まず一意（Req 4.6, upsert 整合）。
@Model
final class Tag {
    @Attribute(.unique) var name: String

    /// このタグが付いたメモ（多対多）。メモ削除では関連解除のみ（nullify）。
    @Relationship(deleteRule: .nullify, inverse: \Memo.tags)
    var memos: [Memo]

    init(name: String) {
        self.name = name
        self.memos = []
    }
}
