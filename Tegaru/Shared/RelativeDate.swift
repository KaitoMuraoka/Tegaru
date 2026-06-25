//
//  RelativeDate.swift
//  Tegaru
//
//  Task 1.3: 共有表示ユーティリティ（相対時刻）
//  Requirements: 2.3, 6.3
//

import Foundation

/// 日時を「3分前」「昨日」などの相対表現へ整形する純関数群。
enum RelativeDate {

    /// 相対時刻文字列を返す。
    /// - Parameters:
    ///   - date: 対象日時（メモの `createdAt` 等）。
    ///   - now: 基準となる現在時刻。テストで固定できるよう注入可能。
    ///   - calendar: 暦日判定に使うカレンダー。
    static func string(from date: Date, relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        let elapsed = now.timeIntervalSince(date)

        // 未来、または1分未満は「たった今」へ丸める。
        if elapsed < 60 { return "たった今" }

        // 同じ暦日内は経過時間で表現する。
        if calendar.isDate(date, inSameDayAs: now) {
            if elapsed < 3600 {
                return "\(Int(elapsed / 60))分前"
            }
            return "\(Int(elapsed / 3600))時間前"
        }

        // 暦日差で「昨日」「N日前」を判定する。
        let startOfDate = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)
        let dayDiff = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day ?? 0

        switch dayDiff {
        case 1:
            return "昨日"
        case 2...6:
            return "\(dayDiff)日前"
        default:
            return absoluteString(for: date, relativeTo: now, calendar: calendar)
        }
    }

    /// 1週間以上前は絶対日付で表す。同年なら「M月D日」、年を跨ぐなら「Y年M月D日」。
    private static func absoluteString(for date: Date, relativeTo now: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        let nowYear = calendar.component(.year, from: now)

        if let year = parts.year, year != nowYear {
            return "\(year)年\(month)月\(day)日"
        }
        return "\(month)月\(day)日"
    }
}
