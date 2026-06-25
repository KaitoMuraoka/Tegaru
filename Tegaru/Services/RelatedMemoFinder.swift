//
//  RelatedMemoFinder.swift
//  Tegaru
//
//  Task 5.3: 関連メモ検索（経路切替）
//  Requirements: 10.1, 10.2, 10.3, 10.4
//

import Foundation
import SwiftData

#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// 経路非依存の関連メモ検索インターフェース。
/// 返却メモは実在し（grounded）対象自身を含まない。対象メモのコンテキスト内で同期実行する。
protocol RelatedMemoFinder {
    func relatedMemos(for memo: Memo, limit: Int) -> [Memo]
}

/// タグ重複スコアによる決定的なフォールバック実装（Req 10.4）。
struct TagOverlapFinder: RelatedMemoFinder {
    func relatedMemos(for memo: Memo, limit: Int) -> [Memo] {
        guard limit > 0, let context = memo.modelContext else { return [] }
        let targetTags = Set(memo.tags.map(\.name))
        guard !targetTags.isEmpty else { return [] }

        let candidates = (try? context.fetch(FetchDescriptor<Memo>())) ?? []
        let scored = candidates
            .filter { $0.id != memo.id && $0.author == nil && $0.parent == nil }   // 過去の自分のルートメモ
            .map { ($0, Set($0.tags.map(\.name)).intersection(targetTags).count) }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                lhs.1 != rhs.1 ? lhs.1 > rhs.1 : lhs.0.createdAt > rhs.0.createdAt
            }
        return Array(scored.prefix(limit).map(\.0))
    }
}

/// 本文の埋め込み類似度による代替実装。埋め込みが使えない場合はタグ重複へフォールバックする（Req 10.4）。
struct EmbeddingFinder: RelatedMemoFinder {
    private let fallback = TagOverlapFinder()

    func relatedMemos(for memo: Memo, limit: Int) -> [Memo] {
        guard limit > 0, let context = memo.modelContext else { return [] }

        #if canImport(NaturalLanguage)
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .japanese)
            ?? NLEmbedding.sentenceEmbedding(for: .english) else {
            return fallback.relatedMemos(for: memo, limit: limit)
        }

        let candidates = ((try? context.fetch(FetchDescriptor<Memo>())) ?? [])
            .filter { $0.id != memo.id && $0.author == nil && $0.parent == nil && !$0.body.isEmpty }

        let scored = candidates
            .map { ($0, embedding.distance(between: memo.body, and: $0.body)) }
            .sorted { $0.1 < $1.1 }   // コサイン距離が小さいほど類似
        return Array(scored.prefix(limit).map(\.0))
        #else
        return fallback.relatedMemos(for: memo, limit: limit)
        #endif
    }
}

/// 起動時に注入する関連メモ検索の実装を選択する。
///
/// iOS 27+ の Foundation Models Spotlight 検索ツール経路はエンジンのセッションツール側で扱う想定のため、
/// ここでは常に grounded で決定的な `TagOverlapFinder` を既定とする（フォールバック常備, Req 10.4）。
enum RelatedMemoFinderFactory {
    static func make() -> RelatedMemoFinder {
        TagOverlapFinder()
    }
}
