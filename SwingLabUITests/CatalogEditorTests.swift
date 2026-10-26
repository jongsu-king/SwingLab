import XCTest

final class CatalogEditorTests: XCTestCase {
    @MainActor func testCatalogSearchSelectionAndSave() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--screenshot-testing", "--screenshot-language", "en",
            "--screenshot-appearance", "light", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let bag = app.buttons["home.bag"]
        XCTAssertTrue(bag.waitForExistence(timeout: 15)); bag.tap()
        let addClub = app.buttons["Add your first club"]
        XCTAssertTrue(addClub.waitForExistence(timeout: 5)); addClub.tap()
        let catalog = app.buttons["bag.catalog"]
        XCTAssertTrue(catalog.waitForExistence(timeout: 5)); catalog.tap()
        XCTAssertTrue(app.buttons["Not in the list"].firstMatch.waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("QÍ10")
        let model = app.buttons["catalog.model.taylormade-2024-driver-qi10"]
        XCTAssertTrue(model.waitForExistence(timeout: 5)); model.tap()
        let variant = app.buttons["catalog.select.taylormade-2024-driver-qi10.Max"]
        XCTAssertTrue(variant.waitForExistence(timeout: 5)); variant.tap()
        XCTAssertTrue(app.buttons["bag.save"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "round4-en-light-catalog-editor"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["bag.save"].tap()
        XCTAssertTrue(app.staticTexts["Qi10 Max"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["Qi10 Max"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
    }
}
