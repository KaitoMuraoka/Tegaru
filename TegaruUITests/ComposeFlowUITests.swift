//
//  ComposeFlowUITests.swift
//  TegaruUITests
//
//  Task 7.5: 主要ユーザーフローの E2E/UI テスト
//  Requirements: 2.7, 5.1, 6.4
//

import XCTest

final class ComposeFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 投稿 → タイムライン降順表示 → セルからスレッド遷移。
    @MainActor
    func testPostAppearsAndOpensThread() throws {
        let app = XCUIApplication()
        app.launch()

        let unique = "UITest-\(Int(Date().timeIntervalSince1970))"

        // FAB からコンポーザーを開く
        app.buttons["composeButton"].tap()

        // 本文入力（vertical TextField は textField/ textView いずれかで出るため両対応）
        let textField = app.textFields["composerTextField"]
        let textView = app.textViews["composerTextField"]
        let input = textField.waitForExistence(timeout: 5) ? textField : textView
        XCTAssertTrue(input.waitForExistence(timeout: 5), "コンポーザー入力欄が表示されること")
        input.tap()
        input.typeText(unique)

        // 投稿
        app.buttons["postButton"].tap()

        // タイムラインに反映される
        let postedCell = app.staticTexts[unique]
        XCTAssertTrue(postedCell.waitForExistence(timeout: 5), "投稿がタイムラインに表示されること")

        // セルタップでスレッド詳細へ遷移
        postedCell.tap()
        XCTAssertTrue(app.navigationBars["スレッド"].waitForExistence(timeout: 5), "スレッド詳細へ遷移すること")
    }
}
