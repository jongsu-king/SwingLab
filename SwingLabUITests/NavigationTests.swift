import XCTest

final class NavigationTests: XCTestCase {
    @MainActor func testOnboardingAndFourTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let start = app.buttons["Get started"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        for label in ["Home", "Swing", "Course", "Performance"] {
            let tab = app.tabBars.buttons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
        }
        XCTAssertEqual(app.tabBars.buttons.count, 4)
    }
}
