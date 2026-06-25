//
//  AppBootstrap.swift
//  Tegaru
//
//  Task 6.1: アプリ起動フローの結線
//  Requirements: 8.1, 12.1, 13.1
//

import Foundation
import SwiftData

/// 起動時の初期化フロー: ペルソナの初回シードと AI 可用性ゲートの確定。
@MainActor
enum AppBootstrap {
    @discardableResult
    static func bootstrap(
        container: ModelContainer,
        provider: AvailabilityProviding = ModelAvailabilityProvider(),
        seeder: PersonaSeeder = PersonaSeeder()
    ) -> AIFeatureGate {
        seeder.seedIfNeeded(in: container.mainContext)
        return AIFeatureGate(provider: provider)
    }
}
