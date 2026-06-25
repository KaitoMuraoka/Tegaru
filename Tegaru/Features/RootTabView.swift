//
//  RootTabView.swift
//  Tegaru
//
//  Task 6.2: タブ構成と AI 縮退表示の結線
//  Requirements: 11.1, 12.2, 12.3, 15.1, 15.2, 15.3
//

import SwiftUI

/// アプリのタブ。フォロー/リツイート/通知等の他者関与機能は持たない（Req 15.2）。
enum AppTab: CaseIterable {
    case home
    case search
    case activity

    /// 表示すべきタブ。AI 無効時はアクティビティを除外する（Req 11.1 / 12.2）。
    static func visible(activityEnabled: Bool) -> [AppTab] {
        activityEnabled ? [.home, .search, .activity] : [.home, .search]
    }
}

struct RootTabView: View {
    let gate: AIFeatureGate

    var body: some View {
        TabView {
            TimelineView()
                .tabItem { Label("ホーム", systemImage: "house") }

            SearchView()
                .tabItem { Label("検索", systemImage: "magnifyingglass") }

            // AI 有効時のみアクティビティタブを出す。無効端末でもコア機能は成立する（Req 12.3）。
            if gate.showsActivityTab {
                ActivityView()
                    .tabItem { Label("アクティビティ", systemImage: "bell") }
            }
        }
    }
}
