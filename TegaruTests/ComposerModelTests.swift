//
//  ComposerModelTests.swift
//  TegaruTests
//
//  Task 3.1: コンポーザー（新規・返信・編集）と入力状態
//  Requirements: 1.2, 1.3, 1.5, 7.1, 7.2, 7.3, 16.1
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct ComposerModelTests {
    struct NoopIndexer: MemoIndexing {
        func index(_ memo: Memo) {}
        func remove(_ id: UUID) {}
    }

    private func makeContext() throws -> ModelContext {
        try AppModelContainer.makeContainer(inMemory: true).mainContext
    }

    private func service(_ context: ModelContext) -> MemoService {
        MemoService(context: context, indexer: NoopIndexer())
    }

    @Test("新規モードは空で投稿不可、入力すると投稿可・文字数を反映する")
    func newModeState() {
        let model = ComposerModel(mode: .new)
        #expect(model.body.isEmpty)
        #expect(model.canPost == false)

        model.body = "やあ"
        #expect(model.canPost == true)
        #expect(model.characterCount == 2)
    }

    @Test("空白のみの本文は投稿不可")
    func whitespaceNotPostable() {
        let model = ComposerModel()
        model.body = "   \n\t "
        #expect(model.canPost == false)
    }

    @Test("文字数に上限はない")
    func noCharacterLimit() {
        let model = ComposerModel()
        model.body = String(repeating: "あ", count: 5_000)
        #expect(model.characterCount == 5_000)
        #expect(model.canPost)
    }

    @Test("編集モードは既存の本文と画像を初期値として読み込む")
    func editModeLoadsInitialValues() throws {
        let context = try makeContext()
        let data = Data([0x01, 0x02])
        let memo = Memo(body: "既存本文 #タグ", imageData: data)
        context.insert(memo)

        let model = ComposerModel(mode: .edit(memo))
        #expect(model.body == "既存本文 #タグ")
        #expect(model.imageData == data)
    }

    @Test("画像は添付・削除できる（1枚）")
    func attachAndRemoveImage() {
        let model = ComposerModel()
        #expect(model.imageData == nil)
        model.attachImage(Data([0xFF]))
        #expect(model.imageData == Data([0xFF]))
        model.removeImage()
        #expect(model.imageData == nil)
    }

    @Test("新規保存はメモサービスへ委譲し createdNew を返す")
    func saveNewDelegates() throws {
        let context = try makeContext()
        let model = ComposerModel(mode: .new)
        model.body = "保存される本文"

        guard case .createdNew = model.save(using: service(context)) else {
            Issue.record("createdNew を返すべき"); return
        }
        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 1)
    }

    @Test("返信保存は parent を設定し createdNew を返す")
    func saveReplySetsParent() throws {
        let context = try makeContext()
        let parent = Memo(body: "親メモ")
        context.insert(parent)
        try context.save()

        let model = ComposerModel(mode: .reply(parent: parent))
        model.body = "返信本文"
        guard case .createdNew = model.save(using: service(context)) else {
            Issue.record("createdNew を返すべき"); return
        }

        #expect(Memo.sortedReplies(of: parent).map(\.body) == ["返信本文"])
    }

    @Test("空本文の保存は failed を返す")
    func saveEmptyFails() throws {
        let context = try makeContext()
        let model = ComposerModel(mode: .new)
        model.body = "   "
        #expect(model.save(using: service(context)) == .failed)
        #expect(try context.fetchCount(FetchDescriptor<Memo>()) == 0)
    }

    @Test("編集保存は updated を返し updatedAt を設定・本文を更新する")
    func saveEditUpdates() throws {
        let context = try makeContext()
        let memo = Memo(body: "旧本文")
        context.insert(memo)
        try context.save()

        let model = ComposerModel(mode: .edit(memo))
        model.body = "新本文"
        #expect(model.save(using: service(context)) == .updated)
        #expect(memo.body == "新本文")
        #expect(memo.updatedAt != nil)
    }
}
