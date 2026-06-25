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

/// スコア付き関連メモ候補。`score` は大きいほど関連が強い。
private struct ScoredMemo {
    let memo: Memo
    let score: Double
}

private extension Memo {
    /// 過去の自分のルートメモ（作者なし・親なし）で、対象自身でないもの。
    func isPastRootCandidate(excluding target: Memo) -> Bool {
        id != target.id && author == nil && parent == nil
    }
}

/// タグ重複スコアによる決定的なフォールバック実装（Req 10.4）。
struct TagOverlapFinder: RelatedMemoFinder {
    func relatedMemos(for memo: Memo, limit: Int) -> [Memo] {
        guard limit > 0, let context = memo.modelContext else { return [] }
        let targetTags = Set(memo.tags.map(\.name))
        guard !targetTags.isEmpty else { return [] }

        let candidates = (try? context.fetch(FetchDescriptor<Memo>())) ?? []

        var scored: [ScoredMemo] = []
        for candidate in candidates {
            guard candidate.isPastRootCandidate(excluding: memo) else { continue }
            let overlap = Set(candidate.tags.map(\.name)).intersection(targetTags).count
            guard overlap > 0 else { continue }
            scored.append(ScoredMemo(memo: candidate, score: Double(overlap)))
        }

        let ordered = scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.memo.createdAt > rhs.memo.createdAt   // 同点は新しい順
        }
        return ordered.prefix(limit).map { $0.memo }
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

        let candidates = (try? context.fetch(FetchDescriptor<Memo>())) ?? []

        var scored: [ScoredMemo] = []
        for candidate in candidates {
            guard candidate.isPastRootCandidate(excluding: memo), !candidate.body.isEmpty else { continue }
            let distance = embedding.distance(between: memo.body, and: candidate.body)
            scored.append(ScoredMemo(memo: candidate, score: -distance))   // 距離が小さいほどスコア大
        }

        let ordered = scored.sorted { $0.score > $1.score }
        return ordered.prefix(limit).map { $0.memo }
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
