import Foundation

public enum PortScanError: Error, LocalizedError {
    case scanFailed(String)

    public var errorDescription: String? {
        switch self {
        case .scanFailed(let reason): return reason
        }
    }
}

public protocol PortScannerProtocol {
    func scan(excludedPorts: Set<Int>, excludedProcessNames: Set<String>) throws -> [PortInfo]
}

public class PortScanner: PortScannerProtocol {
    public init() {}

    public func scan(excludedPorts: Set<Int>, excludedProcessNames: Set<String>) throws -> [PortInfo] {
        guard let output = ShellExecutor.run("/usr/sbin/lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null") else {
            throw PortScanError.scanFailed("Could not run lsof")
        }
        return parse(output: output, excludedPorts: excludedPorts, excludedProcessNames: excludedProcessNames)
    }

    func parse(output: String, excludedPorts: Set<Int>, excludedProcessNames: Set<String>) -> [PortInfo] {
        let lines = output.components(separatedBy: "\n")
        var seen = Set<Int>()
        var results: [PortInfo] = []

        for line in lines.dropFirst() {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 9 else { continue }

            let processName = String(fields[0]).sanitizedProcessName
            guard let pid = Int32(fields[1]) else { continue }

            // NAME is second-to-last; last field is "(LISTEN)"
            guard let port = findPort(in: fields) else { continue }

            if excludedPorts.contains(port) { continue }
            if excludedProcessNames.contains(processName) { continue }
            if seen.contains(port) { continue }

            seen.insert(port)
            results.append(PortInfo(port: port, pid: pid, processName: processName))
        }

        return results.sorted { $0.port < $1.port }
    }

    private func findPort(in fields: [Substring]) -> Int? {
        // Walk backwards to find the field with a port (e.g. *:3000, 127.0.0.1:8000, [::1]:9090)
        for field in fields.reversed() {
            if let port = extractPort(from: String(field)) {
                return port
            }
        }
        return nil
    }

    private func extractPort(from name: String) -> Int? {
        // Format: "*:3000" or "127.0.0.1:8000" or "[::1]:9090"
        guard let colonIndex = name.lastIndex(of: ":") else { return nil }
        let portString = name[name.index(after: colonIndex)...]
        guard let port = Int(portString), (1...65535).contains(port) else { return nil }
        return port
    }
}
