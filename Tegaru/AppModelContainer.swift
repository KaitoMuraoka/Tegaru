//
//  AppModelContainer.swift
//  Tegaru
//
//  Task 1.2: ModelContainer 構築とアプリエントリポイント
//  Requirements: 13.1, 13.2, 13.4
//

import Foundation
import SwiftData

/// アプリ全体で共有する SwiftData コンテナの構築点。
///
/// 端末サンドボックス内にのみ永続化し、外部同期（CloudKit）やネットワークを一切持たない
/// プライバシー完結構成とする（Req 13.1 ローカル完結 / 13.2 オフライン / 13.4 明示同期なし）。
enum AppModelContainer {

    /// アプリが登録する全 `@Model`。スキーマ変更時はここを更新する。
    static let models: [any PersistentModel.Type] = [
        Memo.self,
        Persona.self,
        Tag.self,
        ReactionEvent.self,
    ]

    /// コンテナを構築する。
    /// - Parameters:
    ///   - url: 明示的なストア位置（テストでの再起動再現用）。未指定なら既定のサンドボックス位置。
    ///   - inMemory: メモリ内のみ（テスト用）。`url` 指定時は無視される。
    /// - Note: `cloudKitDatabase: .none` で外部同期を無効化する（Req 13.4）。
    static func makeContainer(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
