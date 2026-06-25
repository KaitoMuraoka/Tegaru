//
//  ActivityQueriesTests.swift
//  TegaruTests
//
//  Task 6.4: アクティビティ一覧と気づき提示の結線
//  Requirements: 10.5, 11.2, 11.3
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct ActivityQueriesTests {
    private func makeContext() throws -> ModelContext {
        try AppModelContainer.makeContainer(inMemory: true).mainContext
    }

    @Test("アクティビティは createdAt 降順で取得する")
    func activityDescending() throws {
        let context = try makeContext()
        let persona = Persona(name: "p", personality: "x", accentColor: "blue")
        context.insert(persona)
        let memo = Memo(body: "m")
        context.insert(memo)
        context.insert(ReactionEvent(kind: .like, createdAt: Date(timeIntervalSince1970: 100), persona: persona, targetMemo: memo))
        context.insert(ReactionEvent(kind: .reply, createdAt: Date(timeIntervalSince1970: 200), persona: persona, targetMemo: memo))
        try context.save()

        let result = try context.fetch(ReactionEvent.activityDescriptor)
        #expect(result.map(\.kind) == [.reply, .like])
    }

    @Test("対象メモの気づきイベントのみを抽出する")
    func insightsFilter() {
        let persona = Persona(name: "p", personality: "x", accentColor: "blue")
        let a = Memo(body: "A")
        let b = Memo(body: "B")
        let insightA = ReactionEvent(kind: .insight, persona: persona, targetMemo: a, insightText: "気づきA")
        let likeA = ReactionEvent(kind: .like, persona: persona, targetMemo: a)
        let insightB = ReactionEvent(kind: .insight, persona: persona, targetMemo: b, insightText: "気づきB")

        let result = ReactionEvent.insights(in: [insightA, likeA, insightB], forTargetID: a.id)
        #expect(result.count == 1)
        #expect(result.first?.insightText == "気づきA")
    }

    @Test("threadRoot は親をたどってスレッドのルートを返す")
    func threadRootResolves() {
        let root = Memo(body: "root")
        let child = Memo(body: "child", parent: root)
        let grandchild = Memo(body: "grandchild", parent: child)

        #expect(grandchild.threadRoot.id == root.id)
        #expect(root.threadRoot.id == root.id)
    }
}
