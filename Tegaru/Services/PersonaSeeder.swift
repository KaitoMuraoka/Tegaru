//
//  PersonaSeeder.swift
//  Tegaru
//
//  Task 5.1: プリセットペルソナの初回シード
//  Requirements: 8.1, 8.2
//

import Foundation
import SwiftData

/// 初回起動時にプリセットペルソナを投入する。既存があれば何もしない（冪等）。
struct PersonaSeeder {
    /// 性格・表示名・識別色の異なるプリセット群。
    static let presets: [(name: String, personality: String, accentColor: String)] = [
        ("きょうこ", "いつも明るく共感的に、相手の気持ちへ寄り添って短くカジュアルに返す。", "pink"),
        ("ハカセ", "理屈っぽく分析的。事実や背景知識を交えて短く落ち着いて解説する。", "blue"),
        ("ツッコミ", "鋭くユーモラスにツッコミを入れる。軽口だが悪意はなく前向き。", "orange"),
    ]

    func seedIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Persona>())) ?? 0
        guard existing == 0 else { return }

        for preset in Self.presets {
            context.insert(Persona(
                name: preset.name,
                personality: preset.personality,
                accentColor: preset.accentColor
            ))
        }
        try? context.save()
    }
}
