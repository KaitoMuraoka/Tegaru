//
//  SpotlightIndexer.swift
//  Tegaru
//
//  Task 2.3: Spotlight インデックス管理
//  Requirements: 10.3, 16.5
//

import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// メモを検索可能項目として登録/更新/除去する高レベル契約。MemoService はこの抽象に依存する。
protocol MemoIndexing {
    func index(_ memo: Memo)
    func remove(_ id: UUID)
}

/// Core Spotlight への低レベル操作。テスト時はフェイクを注入して検証する。
protocol SpotlightIndexClient {
    func index(_ items: [CSSearchableItem])
    func deleteItems(withIdentifiers identifiers: [String])
}

/// `CSSearchableIndex.default()` を用いた本番クライアント。
struct DefaultSpotlightIndexClient: SpotlightIndexClient {
    func index(_ items: [CSSearchableItem]) {
        CSSearchableIndex.default().indexSearchableItems(items)
    }

    func deleteItems(withIdentifiers identifiers: [String]) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
    }
}

/// メモを Core Spotlight の検索可能項目として索引管理する。
/// 識別子に `Memo.id` を用いるため、再索引は同一識別子での upsert、削除は識別子指定で除去される。
struct SpotlightIndexer: MemoIndexing {
    static let domainIdentifier = "memo"

    var client: SpotlightIndexClient = DefaultSpotlightIndexClient()

    func index(_ memo: Memo) {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = String(memo.body.prefix(40))
        attributes.contentDescription = memo.body

        let item = CSSearchableItem(
            uniqueIdentifier: memo.id.uuidString,
            domainIdentifier: Self.domainIdentifier,
            attributeSet: attributes
        )
        client.index([item])
    }

    func remove(_ id: UUID) {
        client.deleteItems(withIdentifiers: [id.uuidString])
    }
}
