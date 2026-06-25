//
//  Memo+Queries.swift
//  Tegaru
//
//  Task 3.2 / 3.3 / 3.4: タイムライン・スレッド・検索のデータストア側クエリ
//  Requirements: 2.1, 2.2, 5.1, 5.3, 5.4, 6.1, 6.2, 14.2
//

import Foundation
import SwiftData

extension Memo {
    /// タイムライン: ルートメモ（`author == nil && parent == nil`）を `createdAt` 降順で取得する。
    static var timelineDescriptor: FetchDescriptor<Memo> {
        FetchDescriptor<Memo>(
            predicate: #Predicate { $0.author == nil && $0.parent == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// 本文の部分一致検索（`createdAt` 降順）。
    static func searchByBody(_ query: String) -> FetchDescriptor<Memo> {
        FetchDescriptor<Memo>(
            predicate: #Predicate { $0.body.localizedStandardContains(query) },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// 指定タグ名を持つメモの絞り込み（`createdAt` 降順）。
    static func searchByTag(_ name: String) -> FetchDescriptor<Memo> {
        FetchDescriptor<Memo>(
            predicate: #Predicate { memo in memo.tags.contains { $0.name == name } },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// スレッド表示用に返信を `createdAt` 昇順で返す。
    static func sortedReplies(of parent: Memo) -> [Memo] {
        parent.replies.sorted { $0.createdAt < $1.createdAt }
    }

    /// ペルソナ（AI）による返信かどうか（`author != nil`）。
    var isPersonaReply: Bool { author != nil }
}
