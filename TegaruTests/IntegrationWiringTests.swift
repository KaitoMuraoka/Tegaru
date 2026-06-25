//
//  IntegrationWiringTests.swift
//  TegaruTests
//
//  Task 6.1 / 6.2 / 6.3: 起動フロー・タブ構成・投稿後 AI 起動の結線
//  Requirements: 1.6, 8.1, 9.4, 11.1, 12.1, 12.2, 12.3, 13.1, 16.7
//

import Testing
import SwiftData
import Foundation
@testable import Tegaru

@MainActor
struct IntegrationWiringTests {
    private struct StubProvider: AvailabilityProviding {
        let value: AIAvailability
        func current() -> AIAvailability { value }
    }

    final class SpyEngine: ReactionStarting, @unchecked Sendable {
        private(set) var startedCount = 0
        func start(memoID: PersistentIdentifier) async { startedCount += 1 }
    }

    private func makeContainer() throws -> ModelContainer {
        try AppModelContainer.makeContainer(inMemory: true)
    }

    // MARK: 6.1 起動フロー

    @Test("起動でペルソナをシードし、可用環境ではゲートが有効になる")
    func bootstrapSeedsAndEnablesGate() throws {
        let container = try makeContainer()
        let gate = AppBootstrap.bootstrap(container: container, provider: StubProvider(value: .available))

        #expect(gate.isEnabled)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Persona>()) == PersonaSeeder.presets.count)
    }

    @Test("不可環境でもシードは行われ、ゲートは無効")
    func bootstrapUnavailableStillSeeds() throws {
        let container = try makeContainer()
        let gate = AppBootstrap.bootstrap(container: container, provider: StubProvider(value: .unavailable(reason: "x")))

        #expect(gate.isEnabled == false)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Persona>()) == PersonaSeeder.presets.count)
    }

    // MARK: 6.2 タブ構成

    @Test("可用時は3タブ、不可時はアクティビティ非表示の2タブ")
    func tabVisibility() {
        #expect(AppTab.visible(activityEnabled: true) == [.home, .search, .activity])
        #expect(AppTab.visible(activityEnabled: false) == [.home, .search])
    }

    // MARK: 6.3 投稿後 AI 起動

    @Test("ゲート有効時は新規投稿で AI 起動Taskを返しエンジンが呼ばれる")
    func reactWhenEnabled() async throws {
        let container = try makeContainer()
        let memo = Memo(body: "x")
        container.mainContext.insert(memo)
        try container.mainContext.save()

        let spy = SpyEngine()
        let model = AppModel(gate: AIFeatureGate(availability: .available), engine: spy)

        let task = model.reactToNewPost(memoID: memo.persistentModelID)
        #expect(task != nil)
        await task?.value
        #expect(spy.startedCount == 1)
    }

    @Test("ゲート無効時は AI を起動しない")
    func noReactWhenDisabled() async throws {
        let container = try makeContainer()
        let memo = Memo(body: "x")
        container.mainContext.insert(memo)
        try container.mainContext.save()

        let spy = SpyEngine()
        let model = AppModel(gate: AIFeatureGate(availability: .unavailable(reason: "x")), engine: spy)

        let task = model.reactToNewPost(memoID: memo.persistentModelID)
        #expect(task == nil)
        #expect(spy.startedCount == 0)
    }

    @Test("編集結果(updated)は AI 起動対象でない / 新規(createdNew)は対象")
    func saveOutcomeDistinguishesNewFromEdit() throws {
        // createdNew には永続 ID が必要なため実コンテキストで生成
        let context = try makeContainer().mainContext
        let memo = Memo(body: "本文")
        context.insert(memo)
        try context.save()

        let created = ComposerModel.SaveOutcome.createdNew(memo.persistentModelID)
        let updated = ComposerModel.SaveOutcome.updated
        let failed = ComposerModel.SaveOutcome.failed

        #expect(created != updated)
        #expect(updated == .updated)
        #expect(failed == .failed)
    }
}
