//
//  ModelAvailabilityProvider.swift
//  Tegaru
//
//  Task 4: AI 可用性判定と縮退ゲート
//  Requirements: 12.1, 12.2, 12.3
//

import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

/// オンデバイス AI の可用性。
enum AIAvailability: Equatable {
    case available
    case unavailable(reason: String)
}

/// 可用性の供給元。テスト時はフェイクを注入できるよう抽象化する。
protocol AvailabilityProviding {
    func current() -> AIAvailability
}

/// `SystemLanguageModel.default.availability`（Foundation Models）をラップする本番プロバイダ。
/// Foundation Models 非対応の SDK / OS では常に `.unavailable` を返す（コアは縮退して稼働, Req 12.3）。
struct ModelAvailabilityProvider: AvailabilityProviding {
    func current() -> AIAvailability {
        let result = resolve()
        switch result {
        case .available:
            AppLog.ai.info("ModelAvailability: available")
        case .unavailable(let reason):
            AppLog.ai.notice("ModelAvailability: unavailable — \(reason, privacy: .public)")
        }
        return result
    }

    private func resolve() -> AIAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                return .unavailable(reason: String(describing: reason))
            @unknown default:
                return .unavailable(reason: "unknown")
            }
        } else {
            return .unavailable(reason: "OS が Foundation Models 非対応")
        }
        #else
        return .unavailable(reason: "Foundation Models が SDK に存在しない（canImport=false）")
        #endif
    }
}
