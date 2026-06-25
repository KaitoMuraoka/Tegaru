//
//  TimelinePerformanceTests.swift
//  TegaruTests
//
//  Task 7.5: パフォーマンステスト（数千件規模のデータストア側ソート）
//  Requirements: 14.1, 14.2
//

import XCTest
import SwiftData
@testable import Tegaru

/// Swift Testing には measure 相当が無いため、性能計測は XCTest で行う。
final class TimelinePerformanceTests: XCTestCase {

    @MainActor
    func testTimelineFetchAmongThousands() throws {
        let container = try AppModelContainer.makeContainer(inMemory: true)
        let context = container.mainContext

        for i in 0..<3_000 {
            context.insert(Memo(body: "メモ\(i) #tag\(i % 20)", createdAt: Date(timeIntervalSince1970: TimeInterval(i))))
        }
        try context.save()

        measure {
            let result = (try? context.fetch(Memo.timelineDescriptor)) ?? []
            XCTAssertEqual(result.count, 3_000)
            // データストア側ソートで最新が先頭
            XCTAssertEqual(result.first?.body, "メモ2999 #tag19")
        }
    }

    @MainActor
    func testBodySearchAmongThousands() throws {
        let container = try AppModelContainer.makeContainer(inMemory: true)
        let context = container.mainContext

        for i in 0..<3_000 {
            context.insert(Memo(body: "メモ\(i)", createdAt: Date(timeIntervalSince1970: TimeInterval(i))))
        }
        try context.save()

        measure {
            let result = (try? context.fetch(Memo.searchByBody("メモ123"))) ?? []
            XCTAssertFalse(result.isEmpty)
        }
    }
}
