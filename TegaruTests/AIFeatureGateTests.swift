//
//  AIFeatureGateTests.swift
//  TegaruTests
//
//  Task 4: AI 可用性判定と縮退ゲート
//  Requirements: 12.1, 12.2, 12.3
//

import Testing
@testable import Tegaru

@MainActor
struct AIFeatureGateTests {
    struct FakeProvider: AvailabilityProviding {
        let value: AIAvailability
        func current() -> AIAvailability { value }
    }

    @Test("可用時はフラグ有効・アクティビティタブ表示")
    func availableEnables() {
        let gate = AIFeatureGate(availability: .available)
        #expect(gate.isEnabled)
        #expect(gate.showsActivityTab)
    }

    @Test("不可時はフラグ無効・アクティビティタブ非表示")
    func unavailableDisables() {
        let gate = AIFeatureGate(availability: .unavailable(reason: "テスト不可"))
        #expect(gate.isEnabled == false)
        #expect(gate.showsActivityTab == false)
    }

    @Test("プロバイダの判定結果でフラグが決まる")
    func usesProvider() {
        let enabled = AIFeatureGate(provider: FakeProvider(value: .available))
        #expect(enabled.isEnabled)

        let disabled = AIFeatureGate(provider: FakeProvider(value: .unavailable(reason: "x")))
        #expect(disabled.isEnabled == false)
    }

    @Test("可用時のみ AI 起動経路が実行される（不可時は抑止）")
    func runWhenEnabledGates() {
        var launchCount = 0

        let enabled = AIFeatureGate(availability: .available)
        #expect(enabled.runWhenEnabled { launchCount += 1 } == true)
        #expect(launchCount == 1)

        let disabled = AIFeatureGate(availability: .unavailable(reason: "x"))
        #expect(disabled.runWhenEnabled { launchCount += 1 } == false)
        #expect(launchCount == 1)   // 不可時は呼ばれないので増えない
    }

    @Test("AIAvailability は理由まで含めて等価判定できる")
    func availabilityEquatable() {
        #expect(AIAvailability.available == .available)
        #expect(AIAvailability.unavailable(reason: "a") == .unavailable(reason: "a"))
        #expect(AIAvailability.unavailable(reason: "a") != .unavailable(reason: "b"))
        #expect(AIAvailability.available != .unavailable(reason: "a"))
    }

    @Test("実プロバイダは環境に応じた可用性を返す（クラッシュしない）")
    func realProviderReturnsValue() {
        switch ModelAvailabilityProvider().current() {
        case .available, .unavailable:
            #expect(Bool(true))
        }
    }
}
