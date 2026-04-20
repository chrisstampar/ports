import XCTest
@testable import PortsLib

final class PortScannerTests: XCTestCase {
    private let scanner = PortScanner()

    // Fixture: realistic lsof output
    private let sampleOutput = """
    COMMAND     PID     USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    node      45678 testuser   23u  IPv6 0xabcdef1234      0t0  TCP *:3000 (LISTEN)
    node      45678 testuser   24u  IPv4 0xabcdef5678      0t0  TCP *:3000 (LISTEN)
    python3   45679 testuser    5u  IPv4 0xabcdef9012      0t0  TCP 127.0.0.1:8000 (LISTEN)
    ruby      45680 testuser    8u  IPv4 0xabcdef3456      0t0  TCP *:4567 (LISTEN)
    rapportd    412 testuser    4u  IPv4 0xabcdef7890      0t0  TCP *:49200 (LISTEN)
    ControlCe   413 testuser    9u  IPv4 0xabcdef2345      0t0  TCP *:7000 (LISTEN)
    go        45681 testuser   10u  IPv6 0xabcdef6789      0t0  TCP [::1]:9090 (LISTEN)
    """

    func testParseBasicOutput() {
        let results = scanner.parse(output: sampleOutput, excludedPorts: [], excludedProcessNames: [])
        XCTAssertGreaterThanOrEqual(results.count, 5)
    }

    func testParseExtractsPort() {
        let results = scanner.parse(output: sampleOutput, excludedPorts: [], excludedProcessNames: [])
        let ports = results.map(\.port)
        XCTAssertTrue(ports.contains(3000))
        XCTAssertTrue(ports.contains(8000))
        XCTAssertTrue(ports.contains(4567))
    }

    func testParseExtractsPID() {
        let results = scanner.parse(output: sampleOutput, excludedPorts: [], excludedProcessNames: [])
        let node = results.first { $0.port == 3000 }
        XCTAssertEqual(node?.pid, 45678)
    }

    func testParseExtractsProcessName() {
        let results = scanner.parse(output: sampleOutput, excludedPorts: [], excludedProcessNames: [])
        let python = results.first { $0.port == 8000 }
        XCTAssertEqual(python?.processName, "python3")
    }

    func testParseIPv6Port() {
        let results = scanner.parse(output: sampleOutput, excludedPorts: [], excludedProcessNames: [])
        let go = results.first { $0.port == 9090 }
        XCTAssertNotNil(go, "Should parse IPv6 [::1]:9090")
        XCTAssertEqual(go?.processName, "go")
    }

    func testDedupeByPort() {
        // Port 3000 appears twice in fixture (IPv6 and IPv4)
        let results = scanner.parse(output: sampleOutput, excludedPorts: [], excludedProcessNames: [])
        let count3000 = results.filter { $0.port == 3000 }.count
        XCTAssertEqual(count3000, 1, "Should dedupe by port")
    }

    func testFilterExcludedPorts() {
        let results = scanner.parse(output: sampleOutput, excludedPorts: [3000, 8000], excludedProcessNames: [])
        let ports = results.map(\.port)
        XCTAssertFalse(ports.contains(3000))
        XCTAssertFalse(ports.contains(8000))
        XCTAssertTrue(ports.contains(4567))
    }

    func testFilterExcludedProcessNames() {
        let results = scanner.parse(output: sampleOutput, excludedPorts: [], excludedProcessNames: ["rapportd", "ControlCe"])
        let names = results.map(\.processName)
        XCTAssertFalse(names.contains("rapportd"))
        XCTAssertFalse(names.contains("ControlCe"))
    }

    func testCombinedFiltering() {
        let results = scanner.parse(
            output: sampleOutput,
            excludedPorts: Constants.defaultExcludedPorts,
            excludedProcessNames: Constants.excludedProcessNames
        )
        let ports = results.map(\.port)
        // 49200 and 7000 are excluded
        XCTAssertFalse(ports.contains(49200))
        XCTAssertFalse(ports.contains(7000))
        // 3000, 8000, 4567, 9090 should remain
        XCTAssertTrue(ports.contains(3000))
        XCTAssertTrue(ports.contains(8000))
    }

    func testResultsSortedByPort() {
        let results = scanner.parse(output: sampleOutput, excludedPorts: [], excludedProcessNames: [])
        let ports = results.map(\.port)
        XCTAssertEqual(ports, ports.sorted())
    }

    func testDefaultStatus() {
        let results = scanner.parse(output: sampleOutput, excludedPorts: [], excludedProcessNames: [])
        for port in results {
            XCTAssertEqual(port.status, .unknown, "Freshly scanned ports should have .unknown status")
        }
    }

    func testEmptyOutput() {
        let results = scanner.parse(output: "", excludedPorts: [], excludedProcessNames: [])
        XCTAssertTrue(results.isEmpty)
    }

    func testHeaderOnly() {
        let header = "COMMAND     PID     USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME"
        let results = scanner.parse(output: header, excludedPorts: [], excludedProcessNames: [])
        XCTAssertTrue(results.isEmpty)
    }

    func testMalformedLine() {
        let bad = """
        COMMAND     PID     USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        bad line
        """
        let results = scanner.parse(output: bad, excludedPorts: [], excludedProcessNames: [])
        XCTAssertTrue(results.isEmpty)
    }

    func testProcessNameUnescapesHexEscape() {
        // lsof can output process names with \x20 for space (e.g. "Adobe\x20")
        let output = """
        COMMAND     PID     USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        Adobe\\x20   99999 testuser    5u  IPv4 0x0      0t0  TCP *:15292 (LISTEN)
        """
        let results = scanner.parse(output: output, excludedPorts: [], excludedProcessNames: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].processName, "Adobe ", "\\x20 should be unescaped to space")
    }
}
