//
//  HashtagExtractor.swift
//  Tegaru
//
//  Task 2.1: ハッシュタグ抽出（純関数）
//  Requirements: 4.1, 4.2, 4.6
//

import Foundation

/// 本文から `#` 直後に続くタグ名を抽出する純関数。
struct HashtagExtractor {
    /// `#` の直後に続く Unicode 文字クラス `\p{L}\p{N}_` の連なりを1つのタグとみなす。
    private static let pattern = "#([\\p{L}\\p{N}_]+)"

    /// 本文からタグ名（先頭 `#` を除く）を出現順・重複排除で返す。
    func extract(from body: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: Self.pattern) else { return [] }

        let nsBody = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: nsBody.length))

        var seen = Set<String>()
        var names: [String] = []
        for match in matches {
            let name = nsBody.substring(with: match.range(at: 1))
            if seen.insert(name).inserted {
                names.append(name)
            }
        }
        return names
    }
}
