//
//  TegaruApp.swift
//  Tegaru
//
//  Created by KaitoMuraoka on 2026/06/25.
//

import SwiftUI
import SwiftData

@main
struct TegaruApp: App {
    /// 端末サンドボックス内に永続化し、外部同期を持たない共有コンテナ（Req 13.1, 13.4）。
    let modelContainer: ModelContainer

    @State private var appModel: AppModel

    init() {
        let container: ModelContainer
        do {
            container = try AppModelContainer.makeContainer()
        } catch {
            fatalError("ModelContainer の構築に失敗しました: \(error)")
        }
        modelContainer = container

        // 起動フローの結線（Task 6.1）: シード + 可用性ゲート確定。
        let gate = AppBootstrap.bootstrap(container: container)

        // リアクションエンジンを構築し、可用性に応じた生成系・RAG 経路を注入する（Task 6.3）。
        let engine = PersonaReactionEngine(modelContainer: container)
        Task {
            await engine.configure(
                generator: ReactionGeneratorFactory.make(),
                relatedFinder: RelatedMemoFinderFactory.make()
            )
        }

        _appModel = State(initialValue: AppModel(gate: gate, engine: engine))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(gate: appModel.gate)
                .environment(appModel)
        }
        .modelContainer(modelContainer)
    }
}
