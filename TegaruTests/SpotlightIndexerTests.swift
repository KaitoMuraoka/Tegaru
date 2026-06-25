//
//  SpotlightIndexerTests.swift
//  TegaruTests
//
//  Task 2.3: Spotlight インデックス管理
//  Requirements: 10.3, 16.5
//

import Testing
import CoreSpotlight
import Foundation
@testable import Tegaru

struct SpotlightIndexerTests {
    /// Core Spotlight への低レベル呼び出しを記録するフェイク。
    final class FakeClient: SpotlightIndexClient {
        var indexed: [CSSearchableItem] = []
        var deleted: [String] = []
        func index(_ items: [CSSearchableItem]) { indexed.append(contentsOf: items) }
        func deleteItems(withIdentifiers identifiers: [String]) { deleted.append(contentsOf: identifiers) }
    }

    @Test("メモを索引へ登録すると識別子付きの項目が追加される")
    func indexesMemo() {
        let fake = FakeClient()
        let indexer = SpotlightIndexer(client: fake)
        let memo = Memo(body: "検索対象の本文 #メモ")

        indexer.index(memo)

        #expect(fake.indexed.count == 1)
        #expect(fake.indexed.first?.uniqueIdentifier == memo.id.uuidString)
        #expect(fake.indexed.first?.attributeSet.contentDescription == "検索対象の本文 #メモ")
    }

    @Test("同一メモの再索引は同じ識別子で upsert される")
    func reindexUsesSameIdentifier() {
        let fake = FakeClient()
        let indexer = SpotlightIndexer(client: fake)
        let memo = Memo(body: "v1")

        indexer.index(memo)
        memo.body = "v2"
        indexer.index(memo)

        #expect(fake.indexed.count == 2)
        #expect(fake.indexed[0].uniqueIdentifier == fake.indexed[1].uniqueIdentifier)
        #expect(fake.indexed[1].attributeSet.contentDescription == "v2")
    }

    @Test("削除すると対応する識別子が索引から除去される")
    func removesByIdentifier() {
        let fake = FakeClient()
        let indexer = SpotlightIndexer(client: fake)
        let id = UUID()

        indexer.remove(id)

        #expect(fake.deleted == [id.uuidString])
    }
}
