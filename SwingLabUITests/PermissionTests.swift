import XCTest

/// Error handling a simulator can reproduce (Acceptance A20). Run with location revoked:
/// `xcrun simctl privacy <device> revoke location com.swinglab.app`, then
/// `xcodebuild … TEST_RUNNER_SWINGLAB_LOCATION_DENIED=1 -only-testing:SwingLabUITests/PermissionTests test`.
/// The simulator camera cannot capture, so the camera path ends in the app's camera error alert.
final class PermissionTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testDeniedLocationAndMissingCameraExplainWhatToDo() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SWINGLAB_LOCATION_DENIED"] == "1")
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--screenshot-testing", "--screenshot-language", "en",
            "--screenshot-appearance", "light", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["Course"].firstMatch.waitForExistence(timeout: 15))

        app.buttons["Course"].firstMatch.tap()
        let refresh = app.buttons["Refresh GPS"].firstMatch
        XCTAssertTrue(refresh.waitForExistence(timeout: 5)); refresh.tap()
        XCTAssertTrue(app.staticTexts["Location access is off. Enable it in iPhone Settings to record GPS shots."]
            .waitForExistence(timeout: 10))
        attach(app, "a20-location-denied")

        app.buttons["Swing"].firstMatch.tap()
        let record = app.buttons["Record swing"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5)); record.tap()
        // Depending on the runtime, the simulator has no camera or a camera that fails at start.
        // Either way the app must say so in an alert and let the user close the camera.
        let alert = app.alerts["Camera"]
        XCTAssertTrue(alert.waitForExistence(timeout: 20))
        let messages = ["This camera is not available on this device.", "The camera stopped. Close the camera and try again.",
                        "The camera could not be configured. Please try again."]
        XCTAssertTrue(messages.contains { alert.staticTexts[$0].exists })
        attach(app, "a20-camera-error")
        alert.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["Close"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Record swing"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
