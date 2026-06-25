//
//  AccentColor.swift
//  Tegaru
//
//  Task 1.3: 共有表示ユーティリティ（アクセントカラー）
//  Requirements: 2.3, 6.3
//

import SwiftUI

/// `Persona.accentColor`（色名文字列）を表示用 `Color` へマッピングするユーティリティ。
enum AccentColor {

    /// 未知の色名に対するフォールバック色。
    static let fallback: Color = .gray

    /// 色名文字列を `Color` へ変換する。大文字小文字は無視し、未知の名前は ``fallback`` を返す。
    static func color(for name: String) -> Color {
        switch name.lowercased() {
        case "red":            return .red
        case "orange":         return .orange
        case "yellow":         return .yellow
        case "green":          return .green
        case "mint":           return .mint
        case "teal":           return .teal
        case "cyan":           return .cyan
        case "blue":           return .blue
        case "indigo":         return .indigo
        case "purple":         return .purple
        case "pink":           return .pink
        case "brown":          return .brown
        case "gray", "grey":   return .gray
        default:               return fallback
        }
    }
}
