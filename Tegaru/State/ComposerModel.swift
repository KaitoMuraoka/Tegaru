//
//  ComposerModel.swift
//  Tegaru
//
//  Task 3.1: コンポーザー（新規・返信・編集）と入力状態
//  Requirements: 1.2, 1.3, 1.5, 7.1, 7.2, 7.3, 16.1
//

import Foundation
import Observation
import SwiftData

/// コンポーザーの入力状態。新規・返信・編集の3モードを表現し、保存はメモサービスへ委譲する。
@MainActor
@Observable
final class ComposerModel {
    enum Mode {
        case new
        case reply(parent: Memo)
        case edit(Memo)
    }

    /// 保存結果。新規/返信は AI リアクション対象（`createdNew`）、編集は対象外（`updated`）。
    enum SaveOutcome: Equatable {
        case createdNew(PersistentIdentifier)
        case updated
        case failed
    }

    let mode: Mode
    var body: String
    var imageData: Data?

    init(mode: Mode = .new) {
        self.mode = mode
        switch mode {
        case .new, .reply:
            self.body = ""
            self.imageData = nil
        case .edit(let memo):
            // 編集モードは対象メモの本文と画像を初期値に読み込む（Req 16.1）。
            self.body = memo.body
            self.imageData = memo.imageData
        }
    }

    /// 現在の文字数（上限なし、Req 1.2 / 1.3）。
    var characterCount: Int { body.count }

    /// 空白のみは投稿不可（Req 1.4 の UI 側無効化）。
    var canPost: Bool { !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var navigationTitle: String {
        switch mode {
        case .new:   return "新規メモ"
        case .reply: return "返信"
        case .edit:  return "編集"
        }
    }

    func attachImage(_ data: Data) { imageData = data }
    func removeImage() { imageData = nil }

    /// 保存をメモサービスへ委譲する。成功時、呼び出し側が画面を閉じる（Req 1.5）。
    /// 新規/返信は `createdNew(id)`（AI 起動対象）、編集は `updated`（AI 非起動, Req 16.7）を返す。
    @discardableResult
    func save(using service: MemoService) -> SaveOutcome {
        switch mode {
        case .new:
            if case .success(let id) = service.create(body: body, imageData: imageData, parent: nil) {
                return .createdNew(id)
            }
        case .reply(let parent):
            if case .success(let id) = service.create(body: body, imageData: imageData, parent: parent) {
                return .createdNew(id)
            }
        case .edit(let memo):
            if case .success = service.update(memo, body: body, imageData: imageData) {
                return .updated
            }
        }
        return .failed
    }
}
