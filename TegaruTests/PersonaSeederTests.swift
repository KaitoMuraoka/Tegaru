//
//  PersonaSeederTests.swift
//  TegaruTests
//
//  Task 5.1: プリセットペルソナの初回シード
//  Requirements: 8.1, 8.2
//

import Testing
import SwiftData
@testable import Tegaru

@MainActor
struct PersonaSeederTests {
    private func makeContext() throws -> ModelContext {
        try AppModelContainer.makeContainer(inMemory: true).mainContext
    }

    @Test("初回は複数の異なるプリセットペルソナを投入する")
    func seedsPresetsOnEmpty() throws {
        let context = try makeContext()
        PersonaSeeder().seedIfNeeded(in: context)

        let personas = try context.fetch(FetchDescriptor<Persona>())
        #expect(personas.count == PersonaSeeder.presets.count)
        #expect(personas.count > 1)
        // name / personality / accentColor が互いに異なる
        #expect(Set(personas.map(\.name)).count == personas.count)
        #expect(Set(personas.map(\.personality)).count == personas.count)
        #expect(Set(personas.map(\.accentColor)).count == personas.count)
    }

    @Test("再実行しても重複生成しない")
    func idempotentSeeding() throws {
        let context = try makeContext()
        let seeder = PersonaSeeder()
        seeder.seedIfNeeded(in: context)
        seeder.seedIfNeeded(in: context)

        #expect(try context.fetchCount(FetchDescriptor<Persona>()) == PersonaSeeder.presets.count)
    }

    @Test("既存ペルソナがあれば何もしない")
    func skipsWhenExisting() throws {
        let context = try makeContext()
        context.insert(Persona(name: "既存", personality: "x", accentColor: "blue"))
        try context.save()

        PersonaSeeder().seedIfNeeded(in: context)
        #expect(try context.fetchCount(FetchDescriptor<Persona>()) == 1)
    }
}
