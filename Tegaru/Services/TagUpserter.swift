//
//  TagUpserter.swift
//  Tegaru
//
//  Task 2.2: タグの解決・作成（upsert）
//  Requirements: 4.3, 4.4
//

import Foundation
import SwiftData

/// タグ名配列を受け取り、同名タグがあれば再利用・無ければ新規作成して返す。
struct TagUpserter {
    /// - Parameters:
    ///   - names: 抽出済みタグ名（重複排除済みを想定するが、内部でも重複に耐える）。
    ///   - context: 解決・作成対象のコンテキスト。
    /// - Returns: 入力順に対応する `Tag` 配列。
    func resolve(_ names: [String], in context: ModelContext) -> [Tag] {
        var resolved: [Tag] = []
        var cache: [String: Tag] = [:]

        for name in names {
            if let cached = cache[name] {
                resolved.append(cached)
                continue
            }

            var descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
            descriptor.fetchLimit = 1

            let tag: Tag
            if let existing = try? context.fetch(descriptor).first {
                tag = existing
            } else {
                tag = Tag(name: name)
                context.insert(tag)
            }
            cache[name] = tag
            resolved.append(tag)
        }
        return resolved
    }
}
