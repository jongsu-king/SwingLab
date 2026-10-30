import XCTest

/// Acceptance A12 (club management in the UI) and A16 (independent units). UI-test launches use an
/// in-memory store and a fresh preferences domain, so nothing here leaks into other tests.
final class BagAndUnitsTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--screenshot-testing", "--screenshot-language", "en",
            "--screenshot-appearance", "light", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor func testCreateEditGapAndDeleteClubs() throws {
        let app = launch()
        let bag = app.buttons["home.bag"]
        XCTAssertTrue(bag.waitForExistence(timeout: 15)); bag.tap()

        try addClub(in: app, opener: app.buttons["Add your first club"], name: "7 iron", carry: "150")
        try addClub(in: app, opener: app.buttons["bag.add"], name: "Pitching wedge", carry: "120")
        // Two carries give the gapping chart.
        XCTAssertTrue(app.staticTexts["Your carry distances"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["7 iron"].exists)
        XCTAssertTrue(app.staticTexts["Pitching wedge"].exists)

        app.staticTexts["7 iron"].tap()
        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); edit.tap()
        let name = app.textFields["Club name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "My 7 iron")
        app.buttons["bag.save"].tap()
        XCTAssertTrue(app.staticTexts["My 7 iron"].waitForExistence(timeout: 5))
        // iPhone Duo names its back button; the compact bar's back button is the first bar button.
        let back = app.buttons["BackButton"].exists ? app.buttons["BackButton"] : app.navigationBars.buttons.element(boundBy: 0)
        if back.exists && !app.staticTexts["Pitching wedge"].exists { back.tap() }

        let wedge = app.staticTexts["Pitching wedge"]
        XCTAssertTrue(wedge.waitForExistence(timeout: 5)); wedge.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        let confirm = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.staticTexts["My 7 iron"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Pitching wedge"].exists)
    }

    /// Distance switches to meters while ball speed stays in mph.
    @MainActor func testDistanceAndSpeedUnitsSwitchIndependently() throws {
        let app = launch()
        let settings = app.buttons["home.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15)); settings.tap()
        let distance = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Distance'")).firstMatch
        XCTAssertTrue(distance.waitForExistence(timeout: 5)); distance.tap()
        let meters = app.buttons["Meters"].firstMatch
        XCTAssertTrue(meters.waitForExistence(timeout: 5)); meters.tap()

        // The tab bar (or the iPhone Duo side rail) stays visible over Settings.
        app.buttons["Swing"].firstMatch.tap()
        try tapRevealed("swing.hypotheticalFlight", in: app)
        try tapRevealed("flight.driverExample", in: app)
        XCTAssertTrue(app.staticTexts["mph"].firstMatch.exists, "ball speed keeps its own unit")
        try tapRevealed("flight.simulate", in: app)
        let carry = app.descendants(matching: .any).matching(identifier: "flight.result.carry").firstMatch
        for _ in 0..<10 where !(carry.exists && carry.isHittable) { app.swipeUp() }
        XCTAssertTrue(carry.exists)
        XCTAssertTrue(carry.label.contains(" m"), carry.label)
        XCTAssertFalse(carry.label.contains("yd"), carry.label)
    }

    @MainActor private func addClub(in app: XCUIApplication, opener: XCUIElement, name: String, carry: String) throws {
        XCTAssertTrue(opener.waitForExistence(timeout: 5)); opener.tap()
        let custom = app.buttons["Not in the list"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5)); custom.tap()
        let nameField = app.textFields["Club name"]
        nameField.tap(); nameField.typeText(name)
        // Close the keyboard before scrolling; on iPhone Duo it otherwise moves the sheet instead.
        let done = app.buttons["keyboard.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        let carryField = app.textFields["Average carry"]
        for _ in 0..<6 where !carryField.isHittable { app.swipeUp() }
        carryField.tap(); carryField.typeText(carry)
        // The decimal pad has no return key; its Done button brings the sheet's Save back on iPhone Duo.
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        // iOS 27 on iPhone Duo hides a scrolled sheet's bar buttons; scrolling back to the top restores Save.
        let save = app.buttons["bag.save"]
        for _ in 0..<6 where !save.exists { app.collectionViews.firstMatch.swipeDown() }
        XCTAssertTrue(save.waitForExistence(timeout: 5)); save.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    @MainActor private func tapRevealed(_ identifier: String, in app: XCUIApplication) throws {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        let clearOfTabBar = app.windows.firstMatch.frame.maxY - 120
        for _ in 0..<10 where !(element.exists && element.isHittable && element.frame.midY < clearOfTabBar) { app.swipeUp() }
        XCTAssertTrue(element.isHittable, identifier)
        element.tap()
    }
}
