import Foundation
import Darwin

public protocol HealthCheckerProtocol {
    func check(port: Int) -> PortInfo.Status
}

public class HealthChecker: HealthCheckerProtocol {
    private let timeout: TimeInterval
    private let slowThreshold: TimeInterval

    public init(
        timeout: TimeInterval = Constants.healthCheckTimeout,
        slowThreshold: TimeInterval = Constants.healthCheckSlowThreshold
    ) {
        self.timeout = timeout
        self.slowThreshold = slowThreshold
    }

    public func check(port: Int) -> PortInfo.Status {
        let start = CFAbsoluteTimeGetCurrent()

        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return .error }
        defer { Darwin.close(sock) }

        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult == 0 {
            return .healthy
        }

        guard errno == EINPROGRESS else {
            return .error
        }

        var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
        let pollResult = poll(&pfd, 1, Int32(timeout * 1000))

        guard pollResult > 0 else { return .error }

        var optval: Int32 = 0
        var optlen = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(sock, SOL_SOCKET, SO_ERROR, &optval, &optlen)

        guard optval == 0 else { return .error }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        return elapsed > slowThreshold ? .slow : .healthy
    }
}
