import XCTest
@testable import PortsLib

final class ShellExecutorTests: XCTestCase {

    func testEchoHello() {
        let output = ShellExecutor.run("echo hello")
        XCTAssertEqual(output, "hello")
    }

    func testEchoWithSpaces() {
        let output = ShellExecutor.run("echo 'hello world'")
        XCTAssertEqual(output, "hello world")
    }

    func testMultilineOutput() {
        let output = ShellExecutor.run("echo 'line1\nline2'")
        XCTAssertNotNil(output)
        XCTAssertTrue(output!.contains("line1"))
        XCTAssertTrue(output!.contains("line2"))
    }

    func testEmptyOutput() {
        let output = ShellExecutor.run("echo -n ''")
        XCTAssertNotNil(output)
    }

    func testFailingCommand() {
        let output = ShellExecutor.run("false")
        XCTAssertNil(output, "A failing command should return nil")
    }

    func testInvalidCommand() {
        let output = ShellExecutor.run("nonexistent_command_xyz_12345 2>/dev/null")
        XCTAssertNil(output)
    }

    func testPwdReturnsPath() {
        let output = ShellExecutor.run("pwd")
        XCTAssertNotNil(output)
        XCTAssertTrue(output!.hasPrefix("/"))
    }

    func testDateReturnsNonEmpty() {
        let output = ShellExecutor.run("date")
        XCTAssertNotNil(output)
        XCTAssertFalse(output!.isEmpty)
    }

    func testTimeoutTerminatesHungCommand() {
        // sleep 60 would exceed a 0.1s timeout; command is terminated and we get nil
        let output = ShellExecutor.run("sleep 60", timeout: 0.1)
        XCTAssertNil(output, "Command that exceeds timeout should return nil")
    }
}
