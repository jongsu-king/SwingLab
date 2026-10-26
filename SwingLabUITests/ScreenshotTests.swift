import XCTest

/// Real UI navigation, with all data empty except a separate DEBUG-only missing-video
/// recording used to reach swing detail. No sample analysis appears in production stores.
final class ScreenshotTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testEnglishLight() throws { try capture(language: "en", appearance: "light") }
    @MainActor func testEnglishDark() throws { try capture(language: "en", appearance: "dark") }
    @MainActor func testKoreanLight() throws { try capture(language: "ko", appearance: "light") }
    @MainActor func testKoreanDark() throws { try capture(language: "ko", appearance: "dark") }
    @MainActor func testGermanLight() throws { try capture(language: "de", appearance: "light") }
    @MainActor func testGermanDark() throws { try capture(language: "de", appearance: "dark") }

    @MainActor private func capture(language: String, appearance: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--screenshot-testing", "--screenshot-language", language,
            "--screenshot-appearance", appearance, "-AppleLanguages", "(\(language))", "-AppleLocale", language]
        app.launch()
        let labels = tabLabels(language)
        XCTAssertTrue(app.buttons[labels[0]].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(labels.filter { app.buttons[$0].firstMatch.exists }.count, 4)
        save(app, screen: "home", language: language, appearance: appearance)

        try tap("home.settings", in: app)
        save(app, screen: "settings", language: language, appearance: appearance)
        // Relaunch the empty test library to return Home; both compact navigation bars
        // and the iPhone Duo side rail follow the same actual startup route.
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons[labels[0]].firstMatch.waitForExistence(timeout: 15))
        try tap("home.bag", in: app)
        save(app, screen: "bag", language: language, appearance: appearance)

        app.buttons[labels[1]].firstMatch.tap()
        save(app, screen: "swing", language: language, appearance: appearance)
        try tap("swing.hypotheticalFlight", in: app)
        try tap("flight.driverExample", in: app)
        try tap("flight.simulate", in: app)
        try reveal("flight.result.carry", in: app)
        save(app, screen: "flight", language: language, appearance: appearance)

        app.buttons[labels[2]].firstMatch.tap()
        save(app, screen: "course", language: language, appearance: appearance)
        app.buttons[labels[3]].firstMatch.tap()
        save(app, screen: "performance", language: language, appearance: appearance)

        app.terminate()
        app.launchArguments.append("--screenshot-empty-recording")
        app.launch()
        XCTAssertTrue(app.buttons[labels[0]].firstMatch.waitForExistence(timeout: 15))
        app.buttons[labels[1]].firstMatch.tap()
        try tap("swing.recording.00000000-0000-0000-0000-000000000003", in: app)
        // The real missing-file error is expected for this intentionally empty detail fixture.
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 5) { alert.buttons.firstMatch.tap() }
        save(app, screen: "swing-detail-empty", language: language, appearance: appearance)
        app.terminate()
    }

    private func tabLabels(_ language: String) -> [String] {
        switch language {
        case "ko": ["홈", "스윙", "코스", "퍼포먼스"]
        case "de": ["Start", "Schwung", "Platz", "Leistung"]
        default: ["Home", "Swing", "Course", "Performance"]
        }
    }

    @MainActor private func tap(_ identifier: String, in app: XCUIApplication) throws {
        try reveal(identifier, in: app)
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch.tap()
    }

    @MainActor private func reveal(_ identifier: String, in app: XCUIApplication) throws {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Required screenshot control was not reachable: \(identifier)")
        throw NSError(domain: "SwingLabScreenshots", code: 1, userInfo: [NSLocalizedDescriptionKey: identifier])
    }

    @MainActor private func save(_ app: XCUIApplication, screen: String, language: String, appearance: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "round3-\(language)-\(appearance)-\(screen)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
