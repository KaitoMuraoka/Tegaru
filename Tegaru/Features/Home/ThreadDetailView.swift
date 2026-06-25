//
//  ThreadDetailView.swift
//  Tegaru
//
//  Task 3.3: スレッド詳細画面
//  Requirements: 6.1, 6.2, 6.3, 6.4, 3.1, 15.5
//

import SwiftUI
import SwiftData

struct ThreadDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let parent: Memo
    @Query(ReactionEvent.activityDescriptor) private var allEvents: [ReactionEvent]
    @State private var showReply = false
    @State private var showDeleteConfirm = false

    private var insights: [ReactionEvent] {
        ReactionEvent.insights(in: allEvents, forTargetID: parent.id)
    }

    private var replies: [Memo] {
        Memo.sortedReplies(of: parent)
    }

    var body: some View {
        List {
            parentSection
            insightsSection
            repliesSection
        }
        .listStyle(.plain)
        .navigationTitle("スレッド")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { replyToolbar }
        .sheet(isPresented: $showReply) {
            ComposerView(mode: .reply(parent: parent))
        }
        .confirmationDialog(
            "このメモを削除しますか？返信もすべて削除されます。",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                MemoService(context: modelContext, indexer: SpotlightIndexer()).delete(parent)
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var parentSection: some View {
        Section {
            MemoRowView(memo: parent)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        if !insights.isEmpty {
            Section("気づき") {
                ForEach(insights) { event in
                    InsightRow(event: event)
                }
            }
        }
    }

    @ViewBuilder
    private var repliesSection: some View {
        if !replies.isEmpty {
            Section("返信") {
                ForEach(replies) { reply in
                    MemoRowView(memo: reply)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var replyToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showReply = true
            } label: {
                Image(systemName: "arrowshape.turn.up.left")
            }
            .accessibilityLabel("返信")
        }
    }
}

/// ペルソナの「気づき」を提示し、参照元メモへ遷移できる行（Req 10.5）。
private struct InsightRow: View {
    let event: ReactionEvent

    @ViewBuilder
    var body: some View {
        if let related = event.relatedMemo {
            NavigationLink(value: related) { content }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AccentColor.color(for: event.persona?.accentColor ?? ""))
                Text("\(event.persona?.name ?? "ペルソナ") の気づき")
                    .font(.caption).bold()
            }
            Text(event.insightText ?? "")
                .font(.callout)
        }
        .padding(.vertical, 2)
    }
}
