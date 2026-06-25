//
//  ComposerView.swift
//  Tegaru
//
//  Task 3.1: コンポーザー（新規・返信・編集）と入力状態
//  Requirements: 1.2, 1.3, 1.5, 7.1, 7.2, 7.3, 16.1
//

import SwiftUI
import SwiftData
import PhotosUI

struct ComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel

    @State private var model: ComposerModel
    @State private var pickerItem: PhotosPickerItem?

    init(mode: ComposerModel.Mode = .new) {
        _model = State(initialValue: ComposerModel(mode: mode))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("いまどうしてる？", text: $model.body, axis: .vertical)
                    .lineLimit(5...)
                    .textFieldStyle(.plain)

                imagePreview

                HStack {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Spacer()
                    Text("\(model.characterCount)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(model.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("投稿") { submit() }
                        .disabled(!model.canPost)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        model.attachImage(data)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let data = model.imageData, let uiImage = UIImage(data: data) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button {
                    pickerItem = nil
                    model.removeImage()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .padding(6)
                }
            }
        }
    }

    /// 保存し、新規/返信のときだけ AI リアクションを起動して画面を閉じる（編集は AI 非起動, Req 16.7）。
    private func submit() {
        switch model.save(using: makeService()) {
        case .createdNew(let memoID):
            appModel.reactToNewPost(memoID: memoID)   // ゲート有効時のみ非同期起動（内部で判定）
            dismiss()
        case .updated:
            dismiss()
        case .failed:
            break   // 空本文等。画面に留まる
        }
    }

    private func makeService() -> MemoService {
        MemoService(context: modelContext, indexer: SpotlightIndexer())
    }
}
