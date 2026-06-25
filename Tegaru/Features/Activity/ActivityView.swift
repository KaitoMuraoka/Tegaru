//
//  ActivityView.swift
//  Tegaru
//
//  Task 6.4: アクティビティ一覧と気づき提示の結線
//  Requirements: 11.2, 11.3
//

import SwiftUI
import SwiftData

struct ActivityView: View {
    @Query(ReactionEvent.activityDescriptor) private var events: [ReactionEvent]

    var body: some View {
        NavigationStack {
            List(events) { event in
                NavigationLink(value: event.targetMemo.threadRoot) {
                    ActivityRow(event: event)
                }
            }
            .listStyle(.plain)
            .navigationTitle("アクティビティ")
            .navigationDestination(for: Memo.self) { ThreadDetailView(parent: $0) }
            .overlay {
                if events.isEmpty {
                    ContentUnavailableView("まだ反応はありません", systemImage: "bell.slash")
                }
            }
        }
    }
}

private struct ActivityRow: View {
    let event: ReactionEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline)
                Text(RelativeDate.string(from: event.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var personaName: String { event.persona?.name ?? "ペルソナ" }

    private var color: Color {
        AccentColor.color(for: event.persona?.accentColor ?? "")
    }

    private var icon: String {
        switch event.kind {
        case .like:    "heart.fill"
        case .reply:   "bubble.right.fill"
        case .insight: "lightbulb.fill"
        }
    }

    private var title: String {
        switch event.kind {
        case .like:    return "\(personaName) がいいねしました"
        case .reply:   return "\(personaName) が返信しました"
        case .insight: return "\(personaName) の気づき"
        }
    }
}
