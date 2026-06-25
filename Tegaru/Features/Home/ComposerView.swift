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
                    Button("投稿") {
                        if model.save(using: makeService()) { dismiss() }
                    }
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

    private func makeService() -> MemoService {
        MemoService(context: modelContext, indexer: SpotlightIndexer())
    }
}
