import XCTest
@testable import PortsLib

final class AppSettingsTests: XCTestCase {
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "AppSettingsTests")!
        testDefaults.removePersistentDomain(forName: "AppSettingsTests")
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "AppSettingsTests")
        super.tearDown()
    }

    func testDefaultScanInterval() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertEqual(settings.scanInterval, Constants.defaultScanInterval)
    }

    func testDefaultExcludedPorts() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertEqual(settings.excludedPorts, Constants.defaultExcludedPorts)
    }

    func testDefaultPortLabelsEmpty() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertTrue(settings.portLabels.isEmpty)
    }

    func testDefaultNotificationsDisabled() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertFalse(settings.notificationsEnabled)
    }

    func testDefaultLaunchAtLoginDisabled() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testPersistScanInterval() {
        let settings = AppSettings(defaults: testDefaults)
        settings.scanInterval = 10.0
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.scanInterval, 10.0)
    }

    func testPersistExcludedPorts() {
        let settings = AppSettings(defaults: testDefaults)
        settings.excludedPorts = [1234, 5678]
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.excludedPorts, [1234, 5678])
    }

    func testPersistPortLabels() {
        let settings = AppSettings(defaults: testDefaults)
        settings.portLabels = [3000: "Frontend", 8000: "API"]
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.portLabels[3000], "Frontend")
        XCTAssertEqual(reloaded.portLabels[8000], "API")
    }

    func testPersistNotificationsEnabled() {
        let settings = AppSettings(defaults: testDefaults)
        settings.notificationsEnabled = true
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertTrue(reloaded.notificationsEnabled)
    }

    func testPersistLaunchAtLogin() {
        let settings = AppSettings(defaults: testDefaults)
        settings.launchAtLogin = true
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertTrue(reloaded.launchAtLogin)
    }

    func testPortLabelsRoundTrip() {
        let settings = AppSettings(defaults: testDefaults)
        let labels: [Int: String] = [80: "HTTP", 443: "HTTPS", 3000: "Dev"]
        settings.portLabels = labels
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.portLabels, labels)
    }
}
