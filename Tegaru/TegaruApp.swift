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

    init() {
        do {
            modelContainer = try AppModelContainer.makeContainer()
        } catch {
            fatalError("ModelContainer の構築に失敗しました: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
