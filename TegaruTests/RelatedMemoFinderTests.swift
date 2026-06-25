//
//  RelatedMemoFinderTests.swift
//  TegaruTests
//
//  Task 5.3: 関連メモ検索（経路切替）
//  Requirements: 10.1, 10.2, 10.4
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct RelatedMemoFinderTests {
    private func makeContext() throws -> ModelContext {
        try AppModelContainer.makeContainer(inMemory: true).mainContext
    }

    private func date(_ t: TimeInterval) -> Date { Date(timeIntervalSince1970: t) }

    @Test("タグ重複数の多い順に返し、対象自身は除外する（grounded）")
    func tagOverlapOrderingAndSelfExclusion() throws {
        let context = try makeContext()
        let a = Tag(name: "A"); let b = Tag(name: "B"); let c = Tag(name: "C")
        [a, b, c].forEach { context.insert($0) }

        let target = Memo(body: "対象 #A #B", createdAt: date(1000)); target.tags = [a, b]
        let both = Memo(body: "両方 #A #B", createdAt: date(100)); both.tags = [a, b]   // overlap 2
        let one = Memo(body: "片方 #A", createdAt: date(200)); one.tags = [a]            // overlap 1
        let none = Memo(body: "無関係 #C", createdAt: date(300)); none.tags = [c]        // overlap 0
        [target, both, one, none].forEach { context.insert($0) }
        try context.save()

        let result = TagOverlapFinder().relatedMemos(for: target, limit: 10)
        #expect(result.map(\.body) == ["両方 #A #B", "片方 #A"])
        #expect(!result.contains { $0.id == target.id })
    }

    @Test("limit で件数を制限する")
    func respectsLimit() throws {
        let context = try makeContext()
        let a = Tag(name: "A"); context.insert(a)
        let target = Memo(body: "対象 #A"); target.tags = [a]
        context.insert(target)
        for i in 0..<5 {
            let memo = Memo(body: "過去\(i) #A", createdAt: date(TimeInterval(i))); memo.tags = [a]
            context.insert(memo)
        }
        try context.save()

        #expect(TagOverlapFinder().relatedMemos(for: target, limit: 2).count == 2)
    }

    @Test("タグが無ければ関連メモは返らない")
    func noTagsNoResults() throws {
        let context = try makeContext()
        let target = Memo(body: "タグなし")
        context.insert(target)
        try context.save()

        #expect(TagOverlapFinder().relatedMemos(for: target, limit: 5).isEmpty)
    }

    @Test("ファクトリは grounded な関連メモ検索を返す")
    func factoryProvidesFinder() throws {
        let context = try makeContext()
        let a = Tag(name: "A"); context.insert(a)
        let target = Memo(body: "対象 #A", createdAt: date(2)); target.tags = [a]
        let other = Memo(body: "他 #A", createdAt: date(1)); other.tags = [a]
        [target, other].forEach { context.insert($0) }
        try context.save()

        let finder = RelatedMemoFinderFactory.make()
        let result = finder.relatedMemos(for: target, limit: 5)
        #expect(result.contains { $0.id == other.id })
        #expect(!result.contains { $0.id == target.id })
    }
}
