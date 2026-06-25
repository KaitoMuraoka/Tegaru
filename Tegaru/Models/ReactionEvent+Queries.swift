//
//  ReactionEvent+Queries.swift
//  Tegaru
//
//  Task 6.4: アクティビティ一覧と気づき提示の結線
//  Requirements: 10.5, 11.2
//

import Foundation
import SwiftData

extension ReactionEvent {
    /// アクティビティ一覧: リアクションを `createdAt` 降順で取得する（Req 11.2）。
    static var activityDescriptor: FetchDescriptor<ReactionEvent> {
        FetchDescriptor<ReactionEvent>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    }

    /// 指定メモを対象とする「気づき」イベントのみを抽出する（スレッドでの気づき提示, Req 10.5）。
    static func insights(in events: [ReactionEvent], forTargetID id: UUID) -> [ReactionEvent] {
        events.filter { $0.kind == .insight && $0.targetMemo.id == id }
    }
}
