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
            // Newer iPhone layouts can expose the tab rail outside an XCUI TabBar.
            let tab = app.buttons[label].firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
        }
        XCTAssertEqual(["Home", "Swing", "Course", "Performance"].filter { app.buttons[$0].firstMatch.exists }.count, 4)
    }
}
