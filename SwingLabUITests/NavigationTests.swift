import XCTest

final class NavigationTests: XCTestCase {
    @MainActor func testOnboardingAndFourTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let start = app.buttons["Get started"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let record = app.buttons["home.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(app.buttons["Swing"].firstMatch.isSelected)
        XCTAssertFalse(app.buttons["home.record"].exists)
        XCTAssertFalse(app.buttons["Stop recording"].exists)
        app.buttons["Home"].firstMatch.tap()
        XCTAssertTrue(app.buttons["home.record"].exists)
        for label in ["Home", "Swing", "Course", "Performance"] {
            // Newer iPhone layouts can expose the tab rail outside an XCUI TabBar.
            let tab = app.buttons[label].firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
        }
        XCTAssertEqual(["Home", "Swing", "Course", "Performance"].filter { app.buttons[$0].firstMatch.exists }.count, 4)
    }
}
