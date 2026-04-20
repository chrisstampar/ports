import XCTest
import Darwin
@testable import PortsLib

final class HealthCheckerTests: XCTestCase {
    private let checker = HealthChecker(timeout: 2.0, slowThreshold: 1.0)

    private var listenerSocket: Int32 = -1
    private var listenerPort: Int = 0

    override func setUp() {
        super.setUp()
        startListener()
    }

    override func tearDown() {
        stopListener()
        super.tearDown()
    }

    private func startListener() {
        listenerSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard listenerSocket >= 0 else { return }

        var opt: Int32 = 1
        setsockopt(listenerSocket, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0  // Let OS pick a port
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.bind(listenerSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(listenerSocket)
            listenerSocket = -1
            return
        }

        listen(listenerSocket, 16)

        var boundAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                getsockname(listenerSocket, sockPtr, &addrLen)
            }
        }
        listenerPort = Int(in_port_t(bigEndian: boundAddr.sin_port))
    }

    private func stopListener() {
        if listenerSocket >= 0 {
            Darwin.close(listenerSocket)
            listenerSocket = -1
        }
    }

    func testHealthyPort() {
        guard listenerPort > 0 else {
            XCTFail("Could not start test listener")
            return
        }
        let status = checker.check(port: listenerPort)
        XCTAssertEqual(status, .healthy)
    }

    func testUnboundPortReturnsError() {
        // Use a port that is very unlikely to be bound
        let status = checker.check(port: 19999)
        XCTAssertEqual(status, .error)
    }

    func testMultipleChecks() {
        guard listenerPort > 0 else { return }
        for _ in 0..<5 {
            let status = checker.check(port: listenerPort)
            XCTAssertEqual(status, .healthy)
        }
    }

    func testAfterListenerStopped() {
        guard listenerPort > 0 else { return }
        let port = listenerPort
        stopListener()
        let status = checker.check(port: port)
        XCTAssertEqual(status, .error)
    }
}
