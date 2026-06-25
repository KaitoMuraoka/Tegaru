//
//  AIFeatureGate.swift
//  Tegaru
//
//  Task 4: AI 可用性判定と縮退ゲート
//  Requirements: 12.1, 12.2, 12.3
//

import Foundation
import Observation

/// AI 機能の縮退を制御する単一判定点。
///
/// 起動時に1度可用性を確定し、`isEnabled` を「アクティビティタブ表示」と
/// 「リアクションエンジン起動」の唯一の条件として供給する（Req 12.1, 12.2）。
/// 無効時もコア機能は無条件に稼働する（Req 12.3）。
@MainActor
@Observable
final class AIFeatureGate {
    private(set) var availability: AIAvailability

    init(availability: AIAvailability) {
        self.availability = availability
    }

    /// 起動時に可用性を1度評価する。
    convenience init(provider: AvailabilityProviding = ModelAvailabilityProvider()) {
        self.init(availability: provider.current())
    }

    /// AI 機能フラグ（タブ表示・エンジン起動の条件）。
    var isEnabled: Bool { availability == .available }

    /// アクティビティタブを表示するか（Req 11.1 / 12.2）。
    var showsActivityTab: Bool { isEnabled }

    /// 有効な場合に限り `action` を実行する（AI 起動経路の単一抑止点, Req 12.2）。
    /// - Returns: 実行したら true、無効で抑止したら false。
    @discardableResult
    func runWhenEnabled(_ action: () -> Void) -> Bool {
        guard isEnabled else { return false }
        action()
        return true
    }
}
