//
//  SearchView.swift
//  Tegaru
//
//  Task 3.4: 検索画面
//  Requirements: 5.1, 5.2, 5.3, 5.4, 14.2
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var query = ""
    @State private var selectedTag: String?
    @State private var results: [Memo] = []

    var body: some View {
        NavigationStack {
            List {
                if !allTags.isEmpty {
                    Section("タグ") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(allTags) { tag in
                                    Button {
                                        selectTag(tag.name)
                                    } label: {
                                        Text("#\(tag.name)")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(selectedTag == tag.name ? .accentColor : .secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    ForEach(results) { memo in
                        NavigationLink(value: memo) {
                            MemoRowView(memo: memo)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("検索")
            .navigationDestination(for: Memo.self) { ThreadDetailView(parent: $0) }
            .searchable(text: $query, prompt: "本文を検索")
            .onChange(of: query) { _, _ in
                selectedTag = nil
                runSearch()
            }
        }
    }

    private func selectTag(_ name: String) {
        selectedTag = (selectedTag == name) ? nil : name
        runSearch()
    }

    private func runSearch() {
        do {
            if let tag = selectedTag {
                results = try modelContext.fetch(Memo.searchByTag(tag))
            } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                results = try modelContext.fetch(Memo.searchByBody(query))
            } else {
                results = []
            }
        } catch {
            results = []
        }
    }
}
