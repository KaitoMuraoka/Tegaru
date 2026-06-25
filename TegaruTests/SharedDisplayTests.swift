//
//  SharedDisplayTests.swift
//  TegaruTests
//
//  Task 1.3: 共有表示ユーティリティ（相対時刻・アクセントカラー）
//  Requirements: 2.3, 6.3
//

import Testing
import SwiftUI
import Foundation
@testable import Tegaru

struct RelativeDateTests {

    /// 決定的に検証するため UTC・グレゴリオ暦の固定カレンダーを使う。
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "ja_JP")
        return cal
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    @Test("1分未満は「たった今」")
    func justNow() {
        let now = date(2026, 6, 25, 12, 0, 0)
        #expect(RelativeDate.string(from: now.addingTimeInterval(-30), relativeTo: now, calendar: calendar) == "たった今")
    }

    @Test("同日・分単位は「N分前」")
    func minutesAgo() {
        let now = date(2026, 6, 25, 12, 0, 0)
        #expect(RelativeDate.string(from: now.addingTimeInterval(-180), relativeTo: now, calendar: calendar) == "3分前")
    }

    @Test("同日・時間単位は「N時間前」")
    func hoursAgo() {
        let now = date(2026, 6, 25, 12, 0, 0)
        let twoHours = date(2026, 6, 25, 10, 0, 0)
        #expect(RelativeDate.string(from: twoHours, relativeTo: now, calendar: calendar) == "2時間前")
    }

    @Test("前日は「昨日」")
    func yesterday() {
        let now = date(2026, 6, 25, 12, 0, 0)
        let y = date(2026, 6, 24, 12, 0, 0)
        #expect(RelativeDate.string(from: y, relativeTo: now, calendar: calendar) == "昨日")
    }

    @Test("数日前は「N日前」")
    func daysAgo() {
        let now = date(2026, 6, 25, 12, 0, 0)
        let threeDays = date(2026, 6, 22, 12, 0, 0)
        #expect(RelativeDate.string(from: threeDays, relativeTo: now, calendar: calendar) == "3日前")
    }

    @Test("1週間以上前は同年なら「M月D日」")
    func absoluteSameYear() {
        let now = date(2026, 6, 25, 12, 0, 0)
        let old = date(2026, 1, 10, 9, 0, 0)
        #expect(RelativeDate.string(from: old, relativeTo: now, calendar: calendar) == "1月10日")
    }

    @Test("年を跨ぐ場合は「Y年M月D日」")
    func absoluteDifferentYear() {
        let now = date(2026, 6, 25, 12, 0, 0)
        let old = date(2025, 12, 1, 9, 0, 0)
        #expect(RelativeDate.string(from: old, relativeTo: now, calendar: calendar) == "2025年12月1日")
    }

    @Test("未来日時は「たった今」へ丸める")
    func futureIsJustNow() {
        let now = date(2026, 6, 25, 12, 0, 0)
        #expect(RelativeDate.string(from: now.addingTimeInterval(600), relativeTo: now, calendar: calendar) == "たった今")
    }
}

struct AccentColorTests {

    @Test("既知の色名は対応する Color を返す")
    func mapsKnownColors() {
        #expect(AccentColor.color(for: "blue") == Color.blue)
        #expect(AccentColor.color(for: "red") == Color.red)
        #expect(AccentColor.color(for: "green") == Color.green)
        #expect(AccentColor.color(for: "purple") == Color.purple)
    }

    @Test("大文字小文字を無視してマッピングする")
    func caseInsensitive() {
        #expect(AccentColor.color(for: "RED") == Color.red)
        #expect(AccentColor.color(for: "Blue") == Color.blue)
    }

    @Test("未知の色名はフォールバック色を返す")
    func unknownFallsBack() {
        #expect(AccentColor.color(for: "存在しない色") == AccentColor.fallback)
        #expect(AccentColor.color(for: "") == AccentColor.fallback)
    }
}
