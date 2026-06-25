//
//  TagUpserterTests.swift
//  TegaruTests
//
//  Task 2.2: タグの解決・作成（upsert）
//  Requirements: 4.3, 4.4
//

import Testing
import SwiftData
@testable import Tegaru

@MainActor
struct TagUpserterTests {
    private func makeContext() throws -> ModelContext {
        try AppModelContainer.makeContainer(inMemory: true).mainContext
    }

    @Test("既存タグは再利用される")
    func reusesExistingTag() throws {
        let context = try makeContext()
        let existing = Tag(name: "swift")
        context.insert(existing)
        try context.save()

        let result = TagUpserter().resolve(["swift"], in: context)
        #expect(result.count == 1)
        #expect(result.first === existing)
        #expect(try context.fetchCount(FetchDescriptor<Tag>()) == 1)
    }

    @Test("未登録名は新規作成される")
    func createsNewTag() throws {
        let context = try makeContext()
        let result = TagUpserter().resolve(["新タグ"], in: context)
        try context.save()

        #expect(result.first?.name == "新タグ")
        #expect(try context.fetchCount(FetchDescriptor<Tag>()) == 1)
    }

    @Test("既存と新規が混在しても重複作成せず順序を保つ")
    func mixedReuseAndCreate() throws {
        let context = try makeContext()
        context.insert(Tag(name: "既存"))
        try context.save()

        let result = TagUpserter().resolve(["既存", "新規"], in: context)
        try context.save()

        #expect(result.map(\.name) == ["既存", "新規"])
        #expect(try context.fetchCount(FetchDescriptor<Tag>()) == 2)
    }
}
