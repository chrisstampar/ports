import XCTest
@testable import PortsLib

final class ConstantsTests: XCTestCase {

    func testDefaultExcludedPortsContainsAirPlay() {
        XCTAssertTrue(Constants.defaultExcludedPorts.contains(5000))
    }

    func testDefaultExcludedPortsContainsAirPlayAudio() {
        XCTAssertTrue(Constants.defaultExcludedPorts.contains(7000))
    }

    func testDefaultExcludedPortsContainsEphemeralRange() {
        XCTAssertTrue(Constants.defaultExcludedPorts.contains(49152))
        XCTAssertTrue(Constants.defaultExcludedPorts.contains(55000))
        XCTAssertTrue(Constants.defaultExcludedPorts.contains(65535))
    }

    func testDefaultExcludedPortsDoesNotContainCommonDevPorts() {
        XCTAssertFalse(Constants.defaultExcludedPorts.contains(3000))
        XCTAssertFalse(Constants.defaultExcludedPorts.contains(8000))
        XCTAssertFalse(Constants.defaultExcludedPorts.contains(8080))
        XCTAssertFalse(Constants.defaultExcludedPorts.contains(4200))
    }

    func testExcludedProcessNames() {
        XCTAssertTrue(Constants.excludedProcessNames.contains("rapportd"))
        XCTAssertTrue(Constants.excludedProcessNames.contains("ControlCenter"))
        XCTAssertTrue(Constants.excludedProcessNames.contains("ControlCe"))
        XCTAssertTrue(Constants.excludedProcessNames.contains("sharingd"))
    }

    func testExcludedProcessNamesDoesNotContainDevProcesses() {
        XCTAssertFalse(Constants.excludedProcessNames.contains("node"))
        XCTAssertFalse(Constants.excludedProcessNames.contains("python3"))
        XCTAssertFalse(Constants.excludedProcessNames.contains("ruby"))
    }

    func testDefaultScanIntervalInRange() {
        XCTAssertGreaterThanOrEqual(Constants.defaultScanInterval, Constants.minScanInterval)
        XCTAssertLessThanOrEqual(Constants.defaultScanInterval, Constants.maxScanInterval)
    }

    func testMinScanIntervalPositive() {
        XCTAssertGreaterThan(Constants.minScanInterval, 0)
    }

    func testMaxScanIntervalReasonable() {
        XCTAssertLessThanOrEqual(Constants.maxScanInterval, 120)
    }

    func testHealthCheckTimeoutPositive() {
        XCTAssertGreaterThan(Constants.healthCheckTimeout, 0)
    }

    func testSlowThresholdLessThanTimeout() {
        XCTAssertLessThan(Constants.healthCheckSlowThreshold, Constants.healthCheckTimeout)
    }

    func testShellCommandTimeoutPositive() {
        XCTAssertGreaterThan(Constants.shellCommandTimeout, 0)
    }

    func testKillEscalateDelayPositive() {
        XCTAssertGreaterThan(Constants.killEscalateDelay, 0)
    }
}
