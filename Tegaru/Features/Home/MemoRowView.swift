//
//  MemoRowView.swift
//  Tegaru
//
//  Task 3.2: メモ行表示（3.3 でのペルソナ識別も担う）
//  Requirements: 2.3, 2.4, 2.5, 2.6, 6.3, 15.5, 16.6
//

import SwiftUI

struct MemoRowView: View {
    let memo: Memo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if memo.isPersonaReply, let author = memo.author {
                personaHeader(author)
            }

            Text(HashtagHighlighter.attributedString(for: memo.body))
                .font(.body)

            if let data = memo.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            metadata
        }
        .padding(.vertical, 4)
    }

    private func personaHeader(_ author: Persona) -> some View {
        let color = AccentColor.color(for: author.accentColor)
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(author.name)
                .font(.caption).bold()
                .foregroundStyle(color)
            // AI による反応であることを明示する（Req 8.3 / 15.5）。
            Text("AI")
                .font(.caption2)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
        }
    }

    private var metadata: some View {
        HStack(spacing: 12) {
            Text(RelativeDate.string(from: memo.createdAt))
            if memo.updatedAt != nil {
                Text("編集済み")
            }
            Label("\(memo.likedBy.count)", systemImage: "heart")
            if !memo.replies.isEmpty {
                Label("\(memo.replies.count)", systemImage: "bubble.right")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
