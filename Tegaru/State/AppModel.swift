//
//  AppModel.swift
//  Tegaru
//
//  Task 6.3: 投稿後 AI リアクション非同期起動の結線
//  Requirements: 1.6, 9.4, 14.3, 16.7
//

import Foundation
import SwiftData
import Observation
import os

/// リアクションエンジン起動の抽象（テストでスパイ注入可能）。
protocol ReactionStarting: Sendable {
    func start(memoID: PersistentIdentifier) async
}

extension PersonaReactionEngine: ReactionStarting {}

/// アプリ全体で共有する状態とサービスのハブ。AI 起動の単一窓口を提供する。
@MainActor
@Observable
final class AppModel {
    let gate: AIFeatureGate
    private let engine: any ReactionStarting

    init(gate: AIFeatureGate, engine: any ReactionStarting) {
        self.gate = gate
        self.engine = engine
    }

    /// 新規/返信投稿後にゲート有効時のみ AI リアクションを非同期起動する（UI を非ブロック）。
    /// 編集経路ではそもそも呼ばない（呼び出し側が `createdNew` のときだけ呼ぶ, Req 16.7）。
    /// - Returns: 起動した場合は実行 Task、ゲート無効で起動しない場合は nil。
    @discardableResult
    func reactToNewPost(memoID: PersistentIdentifier) -> Task<Void, Never>? {
        guard gate.isEnabled else {
            AppLog.ai.notice("reactToNewPost: ゲート無効のため AI 起動せず")
            return nil
        }
        AppLog.ai.info("reactToNewPost: AI リアクションを起動")
        let engine = self.engine
        return Task { await engine.start(memoID: memoID) }
    }
}
