import XCTest
@testable import PortsLib

// Real NotificationService relies on UNUserNotificationCenter which requires
// a proper app bundle (crashes in SPM test runner). Tests verify behavior
// through the mock; the real service is validated during integration testing.

final class NotificationServiceTests: XCTestCase {

    func testMockRequestPermission() {
        let mock = MockNotificationService()
        XCTAssertFalse(mock.permissionRequested)
        mock.requestPermission()
        XCTAssertTrue(mock.permissionRequested)
    }

    func testMockNotifyPortDown() {
        let mock = MockNotificationService()
        mock.notifyPortDown(port: 3000, projectName: "my-app")
        XCTAssertEqual(mock.portDownNotifications.count, 1)
        XCTAssertEqual(mock.portDownNotifications.first?.port, 3000)
        XCTAssertEqual(mock.portDownNotifications.first?.projectName, "my-app")
    }

    func testMockNotifyPortDownWithoutProjectName() {
        let mock = MockNotificationService()
        mock.notifyPortDown(port: 8080, projectName: nil)
        XCTAssertEqual(mock.portDownNotifications.count, 1)
        XCTAssertNil(mock.portDownNotifications.first?.projectName)
    }

    func testMultipleNotifications() {
        let mock = MockNotificationService()
        mock.notifyPortDown(port: 3000, projectName: "app-a")
        mock.notifyPortDown(port: 8000, projectName: "app-b")
        mock.notifyPortDown(port: 4567, projectName: nil)
        XCTAssertEqual(mock.portDownNotifications.count, 3)
    }

    func testProtocolConformance() {
        let service: NotificationServiceProtocol = MockNotificationService()
        service.requestPermission()
        service.notifyPortDown(port: 1234, projectName: "test")
    }
}

class MockNotificationService: NotificationServiceProtocol {
    var permissionRequested = false
    var portDownNotifications: [(port: Int, projectName: String?)] = []

    func requestPermission() {
        permissionRequested = true
    }

    func notifyPortDown(port: Int, projectName: String?) {
        portDownNotifications.append((port: port, projectName: projectName))
    }
}
