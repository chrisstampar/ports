import XCTest
@testable import PortsLib

// MARK: - Mock scanner

class MockPortScanner: PortScannerProtocol {
    var result: Result<[PortInfo], Error> = .success([])

    func scan(excludedPorts: Set<Int>, excludedProcessNames: Set<String>) throws -> [PortInfo] {
        try result.get()
    }
}

// MARK: - Mock health checker

class MockHealthChecker: HealthCheckerProtocol {
    var statusToReturn: PortInfo.Status = .healthy

    func check(port: Int) -> PortInfo.Status {
        return statusToReturn
    }
}

// MARK: - Mock project resolver

class MockProjectResolver: ProjectResolverProtocol {
    var projectNames: [Int32: String] = [:]
    var invalidatedPids: Set<Int32> = []

    func resolve(pid: Int32) -> String? {
        return projectNames[pid]
    }

    func invalidateCache(for pids: Set<Int32>) {
        invalidatedPids.formUnion(pids)
    }
}

// MARK: - Tests

final class PortMonitorServiceTests: XCTestCase {
    private var mockScanner: MockPortScanner!
    private var mockResolver: MockProjectResolver!
    private var mockHealth: MockHealthChecker!
    private var mockNotifications: MockNotificationService!
    private var settings: AppSettings!
    private var service: PortMonitorService!

    override func setUp() {
        super.setUp()
        mockScanner = MockPortScanner()
        mockResolver = MockProjectResolver()
        mockHealth = MockHealthChecker()
        mockNotifications = MockNotificationService()
        let testDefaults = UserDefaults(suiteName: "PortMonitorServiceTests")!
        testDefaults.removePersistentDomain(forName: "PortMonitorServiceTests")
        settings = AppSettings(defaults: testDefaults)

        service = PortMonitorService(
            scanner: mockScanner,
            resolver: mockResolver,
            healthChecker: mockHealth,
            notificationService: mockNotifications,
            settings: settings
        )
    }

    func testScanPopulatesPorts() {
        let ports = [
            PortInfo(port: 3000, pid: 100, processName: "node"),
            PortInfo(port: 8000, pid: 200, processName: "python3"),
        ]
        mockScanner.result = .success(ports)
        mockHealth.statusToReturn = .healthy

        let expectation = XCTestExpectation(description: "Scan completes")

        service.refresh()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.service.ports.count, 2)
            XCTAssertEqual(self.service.ports[0].port, 3000)
            XCTAssertEqual(self.service.ports[1].port, 8000)
            XCTAssertEqual(self.service.ports[0].status, .healthy)
            XCTAssertNil(self.service.scanError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    func testScanErrorPropagation() {
        mockScanner.result = .failure(PortScanError.scanFailed("test error"))

        let expectation = XCTestExpectation(description: "Error propagated")

        service.refresh()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertNotNil(self.service.scanError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    func testPortDisappearedTriggersNotification() {
        settings.notificationsEnabled = true

        let initial = [PortInfo(port: 3000, pid: 100, processName: "node")]
        mockScanner.result = .success(initial)
        mockHealth.statusToReturn = .healthy

        let firstScan = XCTestExpectation(description: "First scan")

        service.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.service.ports.count, 1)
            firstScan.fulfill()
        }
        wait(for: [firstScan], timeout: 3.0)

        // Port disappears
        mockScanner.result = .success([])
        let secondScan = XCTestExpectation(description: "Second scan")

        service.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.service.ports.count, 0)
            XCTAssertEqual(self.mockNotifications.portDownNotifications.count, 1)
            XCTAssertEqual(self.mockNotifications.portDownNotifications.first?.port, 3000)
            secondScan.fulfill()
        }
        wait(for: [secondScan], timeout: 3.0)
    }

    func testNoNotificationWhenDisabled() {
        settings.notificationsEnabled = false

        let initial = [PortInfo(port: 3000, pid: 100, processName: "node")]
        mockScanner.result = .success(initial)
        mockHealth.statusToReturn = .healthy

        let firstScan = XCTestExpectation(description: "First scan")
        service.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { firstScan.fulfill() }
        wait(for: [firstScan], timeout: 3.0)

        mockScanner.result = .success([])
        let secondScan = XCTestExpectation(description: "Second scan")
        service.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertTrue(self.mockNotifications.portDownNotifications.isEmpty)
            secondScan.fulfill()
        }
        wait(for: [secondScan], timeout: 3.0)
    }

    func testProjectNameResolution() {
        let ports = [PortInfo(port: 3000, pid: 100, processName: "node")]
        mockScanner.result = .success(ports)
        mockResolver.projectNames = [100: "my-app"]
        mockHealth.statusToReturn = .healthy

        let expectation = XCTestExpectation(description: "Resolve")
        service.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.service.ports.first?.projectName, "my-app")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testLabelsApplied() {
        settings.portLabels = [3000: "Frontend"]
        let ports = [PortInfo(port: 3000, pid: 100, processName: "node")]
        mockScanner.result = .success(ports)
        mockHealth.statusToReturn = .healthy

        let expectation = XCTestExpectation(description: "Labels")
        service.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.service.ports.first?.label, "Frontend")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testCacheInvalidationOnPidGone() {
        let initial = [PortInfo(port: 3000, pid: 100, processName: "node")]
        mockScanner.result = .success(initial)
        mockHealth.statusToReturn = .healthy

        let firstScan = XCTestExpectation(description: "First scan")
        service.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { firstScan.fulfill() }
        wait(for: [firstScan], timeout: 3.0)

        mockScanner.result = .success([PortInfo(port: 3000, pid: 200, processName: "node")])
        let secondScan = XCTestExpectation(description: "Second scan")
        service.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertTrue(self.mockResolver.invalidatedPids.contains(100))
            secondScan.fulfill()
        }
        wait(for: [secondScan], timeout: 3.0)
    }

    func testHealthStatusApplied() {
        mockScanner.result = .success([PortInfo(port: 3000, pid: 100, processName: "node")])
        mockHealth.statusToReturn = .error

        let expectation = XCTestExpectation(description: "Health")
        service.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.service.ports.first?.status, .error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
}
