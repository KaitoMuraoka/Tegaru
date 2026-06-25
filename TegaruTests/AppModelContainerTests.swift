//
//  AppModelContainerTests.swift
//  TegaruTests
//
//  Task 1.2: ModelContainer 構築とアプリエントリポイント
//  Requirements: 13.1, 13.2, 13.4
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct AppModelContainerTests {

    @Test("4モデルを登録した ModelContainer を構築できる")
    func buildsContainerWithFourModels() throws {
        let container = try AppModelContainer.makeContainer(inMemory: true)
        // Memo / Persona / Tag / ReactionEvent の4エンティティが登録されている
        #expect(container.schema.entities.count >= 4)

        let names = Set(container.schema.entities.map(\.name))
        #expect(names.isSuperset(of: ["Memo", "Persona", "Tag", "ReactionEvent"]))
    }

    @Test("再起動後もメモが端末内に保持される（オフライン永続化）")
    func persistsMemosAcrossRestart() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tegaru-persist-\(UUID().uuidString).store")
        defer {
            // SwiftData が生成する付随ファイルも含めベストエフォートで掃除
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: url.deletingPathExtension().appendingPathExtension("store\(suffix)")
                )
            }
        }

        // 1回目の起動: メモを1件保存
        do {
            let container = try AppModelContainer.makeContainer(url: url)
            let context = container.mainContext
            context.insert(Memo(body: "再起動後も残るメモ"))
            try context.save()
        }

        // 2回目の起動（同じストア URL）: メモが保持されている
        let container2 = try AppModelContainer.makeContainer(url: url)
        let memos = try container2.mainContext.fetch(FetchDescriptor<Memo>())
        #expect(memos.count == 1)
        #expect(memos.first?.body == "再起動後も残るメモ")
    }
}
