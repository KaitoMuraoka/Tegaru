//
//  TimelineView.swift
//  Tegaru
//
//  Task 3.2: タイムライン画面
//  Requirements: 2.1, 2.2, 2.7, 2.8, 3.1, 3.2, 14.1, 14.2
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext

    // ルートメモを降順でデータストア側ソート（テスト済みの timelineDescriptor を共有）。
    @Query(Memo.timelineDescriptor) private var memos: [Memo]

    @State private var showComposer = false
    @State private var pendingDelete: Memo?

    var body: some View {
        NavigationStack {
            List {
                ForEach(memos) { memo in
                    NavigationLink(value: memo) {
                        MemoRowView(memo: memo)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDelete = memo
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("ホーム")
            .navigationDestination(for: Memo.self) { ThreadDetailView(parent: $0) }
            .overlay(alignment: .bottomTrailing) { composerFAB }
            .sheet(isPresented: $showComposer) { ComposerView(mode: .new) }
            .confirmationDialog(
                "このメモを削除しますか？",
                isPresented: deleteDialogBinding,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) { confirmDelete() }
                Button("キャンセル", role: .cancel) { pendingDelete = nil }
            }
        }
    }

    private var composerFAB: some View {
        Button {
            showComposer = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(radius: 4, y: 2)
        }
        .padding(20)
        .accessibilityLabel("新規メモ")
        .accessibilityIdentifier("composeButton")
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    private func confirmDelete() {
        guard let memo = pendingDelete else { return }
        MemoService(context: modelContext, indexer: SpotlightIndexer()).delete(memo)
        pendingDelete = nil
    }
}
