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
    @State private var showReply = false
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
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

            let replies = Memo.sortedReplies(of: parent)
            if !replies.isEmpty {
                Section("返信") {
                    ForEach(replies) { reply in
                        MemoRowView(memo: reply)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("スレッド")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showReply = true
                } label: {
                    Image(systemName: "arrowshape.turn.up.left")
                }
                .accessibilityLabel("返信")
            }
        }
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
}
