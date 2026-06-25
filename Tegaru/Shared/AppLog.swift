//
//  AppLog.swift
//  Tegaru
//
//  端末内ログのみ（外部送信なし, Req 13.3）。AI 経路の診断に用いる。
//

import os

enum AppLog {
    /// AI（可用性判定・リアクション生成）の診断ログ。Console.app で subsystem "com.tegaru.app" を絞り込む。
    static let ai = Logger(subsystem: "com.tegaru.app", category: "ai")
}
