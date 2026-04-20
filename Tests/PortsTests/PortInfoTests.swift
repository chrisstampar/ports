import XCTest
@testable import PortsLib

final class PortInfoTests: XCTestCase {

    func testIdentifiableByPort() {
        let a = PortInfo(port: 3000, pid: 100, processName: "node")
        let b = PortInfo(port: 3000, pid: 200, processName: "python3")
        XCTAssertEqual(a.id, b.id, "Ports with the same port number should have the same id")
    }

    func testDifferentPortsDifferentIds() {
        let a = PortInfo(port: 3000, pid: 100, processName: "node")
        let b = PortInfo(port: 8000, pid: 100, processName: "node")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testDefaultStatus() {
        let port = PortInfo(port: 3000, pid: 100, processName: "node")
        XCTAssertEqual(port.status, .unknown)
    }

    func testEquality() {
        let a = PortInfo(port: 3000, pid: 100, processName: "node", status: .healthy)
        let b = PortInfo(port: 3000, pid: 100, processName: "node", status: .healthy)
        XCTAssertEqual(a, b)
    }

    func testInequalityByStatus() {
        let a = PortInfo(port: 3000, pid: 100, processName: "node", status: .healthy)
        let b = PortInfo(port: 3000, pid: 100, processName: "node", status: .error)
        XCTAssertNotEqual(a, b)
    }

    func testDisplayNamePrefersLabel() {
        let port = PortInfo(port: 3000, pid: 100, processName: "node", projectName: "my-app", label: "Frontend")
        XCTAssertEqual(port.displayName, "Frontend")
    }

    func testDisplayNameFallsBackToProjectName() {
        let port = PortInfo(port: 3000, pid: 100, processName: "node", projectName: "my-app")
        XCTAssertEqual(port.displayName, "my-app")
    }

    func testDisplayNameFallsBackToProcessName() {
        let port = PortInfo(port: 3000, pid: 100, processName: "node")
        XCTAssertEqual(port.displayName, "node")
    }

    func testDisplayNameForRowHidesSlashAndEmpty() {
        let portSlash = PortInfo(port: 3000, pid: 100, processName: "node", projectName: "/")
        XCTAssertEqual(portSlash.displayNameForRow, "node", "Never show '/' next to port")
        let portEmptyProcess = PortInfo(port: 3000, pid: 100, processName: "/", projectName: "/")
        XCTAssertEqual(portEmptyProcess.displayNameForRow, "—", "Show em dash when both are '/'")
    }

    func testAllStatusCases() {
        let cases = PortInfo.Status.allCases
        XCTAssertTrue(cases.contains(.unknown))
        XCTAssertTrue(cases.contains(.healthy))
        XCTAssertTrue(cases.contains(.slow))
        XCTAssertTrue(cases.contains(.error))
        XCTAssertEqual(cases.count, 4)
    }
}
