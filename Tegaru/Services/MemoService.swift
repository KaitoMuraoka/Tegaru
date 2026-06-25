//
//  MemoService.swift
//  Tegaru
//
//  Task 2.4: メモ投稿・編集・削除サービス
//  Requirements: 1.1, 1.4, 1.7, 3.3, 3.4, 4.5, 7.1, 16.2, 16.3, 16.4, 16.5, 16.7
//

import Foundation
import SwiftData

enum MemoError: Error, Equatable {
    case emptyBody
}

/// メモの投稿・編集・削除を1トランザクションとして集約し、
/// タグ再抽出・Spotlight 索引・削除連鎖の整合を保証する（メインアクター上で `mainContext` を使用）。
@MainActor
struct MemoService {
    let context: ModelContext
    var extractor = HashtagExtractor()
    var tagUpserter = TagUpserter()
    var indexer: MemoIndexing

    /// 投稿。空白のみの本文は拒否する。タグを抽出/upsert して紐づけ、索引へ登録する。
    /// - Returns: 保存したメモの永続 ID（AI エンジン起動に使用）。空本文なら `.emptyBody`。
    func create(body: String, imageData: Data? = nil, parent: Memo? = nil) -> Result<PersistentIdentifier, MemoError> {
        guard !isBlank(body) else { return .failure(.emptyBody) }

        let memo = Memo(body: body, imageData: imageData, parent: parent)
        context.insert(memo)
        memo.tags = tagUpserter.resolve(extractor.extract(from: body), in: context)
        try? context.save()

        indexer.index(memo)
        return .success(memo.persistentModelID)
    }

    /// 編集。本文・画像を更新し `updatedAt` を設定（`createdAt` 不変）、タグを再抽出して差し替え、
    /// 索引を再登録する。AI 再反応はしない（既存の `likedBy`・返信は維持）。
    func update(_ memo: Memo, body: String, imageData: Data?) -> Result<Void, MemoError> {
        guard !isBlank(body) else { return .failure(.emptyBody) }

        memo.body = body
        memo.imageData = imageData
        memo.updatedAt = .now
        memo.tags = tagUpserter.resolve(extractor.extract(from: body), in: context)
        try? context.save()

        indexer.index(memo)
        return .success(())
    }

    /// 削除。通常メモは物理削除、親メモは返信を連鎖削除（SwiftData の削除規則）し、
    /// 削除対象（子孫含む）に対応する索引をすべて除去する。
    func delete(_ memo: Memo) {
        let removedIDs = Self.collectIDs(of: memo)
        context.delete(memo)
        try? context.save()

        for id in removedIDs {
            indexer.remove(id)
        }
    }

    private func isBlank(_ body: String) -> Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// メモ自身と全子孫返信の `id` を集める（cascade 削除される索引を整合させるため）。
    private static func collectIDs(of memo: Memo) -> [UUID] {
        var ids = [memo.id]
        for reply in memo.replies {
            ids.append(contentsOf: collectIDs(of: reply))
        }
        return ids
    }
}
