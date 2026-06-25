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
    /// 作成時刻の降順ソート（共通）。型推論を確定させるため明示的に `Memo` を指定する。
    private static var byCreatedAtDescending: [SortDescriptor<Memo>] {
        [SortDescriptor<Memo>(\.createdAt, order: .reverse)]
    }

    /// タイムライン: ルートメモ（`author == nil && parent == nil`）を `createdAt` 降順で取得する。
    static var timelineDescriptor: FetchDescriptor<Memo> {
        let predicate = #Predicate<Memo> { $0.author == nil && $0.parent == nil }
        return FetchDescriptor<Memo>(predicate: predicate, sortBy: byCreatedAtDescending)
    }

    /// 本文の部分一致検索（`createdAt` 降順）。
    static func searchByBody(_ query: String) -> FetchDescriptor<Memo> {
        let predicate = #Predicate<Memo> { $0.body.localizedStandardContains(query) }
        return FetchDescriptor<Memo>(predicate: predicate, sortBy: byCreatedAtDescending)
    }

    /// 指定タグ名を持つメモの絞り込み（`createdAt` 降順）。
    static func searchByTag(_ name: String) -> FetchDescriptor<Memo> {
        let predicate = #Predicate<Memo> { memo in
            memo.tags.contains { $0.name == name }
        }
        return FetchDescriptor<Memo>(predicate: predicate, sortBy: byCreatedAtDescending)
    }

    /// スレッド表示用に返信を `createdAt` 昇順で返す。
    static func sortedReplies(of parent: Memo) -> [Memo] {
        parent.replies.sorted { $0.createdAt < $1.createdAt }
    }

    /// ペルソナ（AI）による返信かどうか（`author != nil`）。
    var isPersonaReply: Bool { author != nil }

    /// 親をたどってスレッドのルートメモを返す（アクティビティからの遷移先解決に使用, Req 11.3）。
    var threadRoot: Memo {
        var current = self
        while let parent = current.parent {
            current = parent
        }
        return current
    }
}
