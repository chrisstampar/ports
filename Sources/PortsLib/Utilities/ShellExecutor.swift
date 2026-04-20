import Foundation
import Darwin

public enum ShellExecutor {
    /// Runs a shell command and returns trimmed stdout, or nil on failure or timeout.
    /// - Parameters:
    ///   - command: Shell command to run (via /bin/sh -c).
    ///   - timeout: Max seconds before the process is terminated (default from Constants.shellCommandTimeout).
    @discardableResult
    public static func run(_ command: String, timeout: TimeInterval = Constants.shellCommandTimeout) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let timeoutWork = DispatchWorkItem { [weak process] in
            guard let process, process.isRunning else { return }
            process.terminate()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
        process.waitUntilExit()
        timeoutWork.cancel()

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sends SIGTERM (graceful shutdown). If the process still exists after `escalateAfter`, sends SIGKILL.
    @discardableResult
    public static func kill(pid: Int32, escalateAfter: TimeInterval = Constants.killEscalateDelay) -> Bool {
        let term = Darwin.kill(pid, SIGTERM)
        if term != 0 {
            if errno == ESRCH { return true }
            return false
        }
        guard escalateAfter > 0 else { return true }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + escalateAfter) {
            if Darwin.kill(pid, 0) == 0 {
                _ = Darwin.kill(pid, SIGKILL)
            }
        }
        return true
    }
}
