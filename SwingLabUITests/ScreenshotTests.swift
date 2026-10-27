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

    /// The other nine languages in light mode, for the reviewer's layout pass (Acceptance A2, A15).
    /// Runs only when asked: `xcodebuild … TEST_RUNNER_SWINGLAB_ALL_LANGUAGES=1 test`.
    @MainActor func testRemainingLanguagesLight() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SWINGLAB_ALL_LANGUAGES"] == "1")
        for language in Self.remainingLanguages { try capture(language: language, appearance: "light") }
    }

    @MainActor func testRemainingLanguagesDark() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SWINGLAB_ALL_LANGUAGES"] == "1")
        for language in Self.remainingLanguages { try capture(language: language, appearance: "dark") }
    }

    /// Screens the main flow does not reach: the launch log and the add-club editor, in all 12 languages.
    @MainActor func testExtraScreensAllLanguages() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SWINGLAB_ALL_LANGUAGES"] == "1")
        for language in ["en", "ko", "de"] + Self.remainingLanguages {
            for appearance in ["light", "dark"] {
                let app = XCUIApplication()
                app.launchArguments = ["--ui-testing", "--screenshot-testing", "--screenshot-language", language,
                    "--screenshot-appearance", appearance, "-AppleLanguages", "(\(language))", "-AppleLocale", language]
                app.launch()
                let labels = tabLabels(language)
                XCTAssertTrue(app.buttons[labels[0]].firstMatch.waitForExistence(timeout: 15))
                app.buttons[labels[1]].firstMatch.tap()
                try tap("swing.launchLog", in: app)
                save(app, screen: "launch-log", language: language, appearance: appearance)
                app.terminate(); app.launch()
                XCTAssertTrue(app.buttons[labels[0]].firstMatch.waitForExistence(timeout: 15))
                try tap("home.bag", in: app)
                try tap("bag.add", in: app)
                XCTAssertTrue(app.buttons["bag.catalog"].waitForExistence(timeout: 5))
                save(app, screen: "club-editor", language: language, appearance: appearance)
                app.terminate()
            }
        }
    }

    private static let remainingLanguages = ["ja", "zh-Hans", "zh-Hant", "es", "pt-BR", "fr", "it", "th", "vi"]

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
        case "ja": ["ホーム", "スイング", "コース", "パフォーマンス"]
        case "zh-Hans": ["主页", "挥杆", "球场", "表现"]
        case "zh-Hant": ["首頁", "揮桿", "球場", "表現"]
        case "es": ["Inicio", "Swing", "Campo", "Rendimiento"]
        case "pt-BR": ["Início", "Swing", "Campo", "Desempenho"]
        case "fr": ["Accueil", "Swing", "Parcours", "Performances"]
        case "it": ["Home", "Swing", "Campo", "Prestazioni"]
        case "th": ["หน้าหลัก", "วงสวิง", "สนาม", "ผลงาน"]
        case "vi": ["Trang chủ", "Swing", "Sân golf", "Hiệu suất"]
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
        attachment.name = "round4-\(language)-\(appearance)-\(screen)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Targeted refresh after a detail-only localization/layout correction. The normal
/// screenshot script selects ScreenshotTests; this test can update just these six images.
final class DetailScreenshotTests: XCTestCase {
    @MainActor func testEmptyDetailVariants() throws {
        continueAfterFailure = false
        for (language, swingLabel, homeLabel) in [("en", "Swing", "Home"), ("ko", "스윙", "홈"), ("de", "Schwung", "Start")] {
            for appearance in ["light", "dark"] {
                let app = XCUIApplication()
                app.launchArguments = ["--ui-testing", "--screenshot-testing", "--screenshot-empty-recording",
                    "--screenshot-language", language, "--screenshot-appearance", appearance,
                    "-AppleLanguages", "(\(language))", "-AppleLocale", language]
                app.launch()
                XCTAssertTrue(app.buttons[homeLabel].firstMatch.waitForExistence(timeout: 15))
                app.buttons[swingLabel].firstMatch.tap()
                let recording = app.buttons["swing.recording.00000000-0000-0000-0000-000000000003"].firstMatch
                for _ in 0..<8 {
                    if recording.exists && recording.isHittable { break }
                    app.swipeUp()
                }
                XCTAssertTrue(recording.exists && recording.isHittable)
                recording.tap()
                let alert = app.alerts.firstMatch
                if alert.waitForExistence(timeout: 5) { alert.buttons.firstMatch.tap() }
                XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "swing.detail.videoUnavailable").firstMatch.waitForExistence(timeout: 5))
                let measuredLabel = language == "ko" ? "측정값" : language == "de" ? "Gemessen" : "Measured"
                XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", measuredLabel)).firstMatch.exists)
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "round4-\(language)-\(appearance)-swing-detail-empty"
                attachment.lifetime = .keepAlways
                add(attachment)
                app.terminate()
            }
        }
    }
}
