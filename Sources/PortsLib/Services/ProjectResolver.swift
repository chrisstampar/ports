import Foundation

public protocol ProjectResolverProtocol {
    func resolve(pid: Int32) -> String?
    func invalidateCache(for pids: Set<Int32>)
}

public class ProjectResolver: ProjectResolverProtocol {
    private var cache: [Int32: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func resolve(pid: Int32) -> String? {
        lock.lock()
        if let cached = cache[pid] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Prefer CWD so dev servers started from project root (e.g. situation) resolve correctly.
        if let cwd = getCWD(for: pid) {
            if let name = findProjectName(startingAt: cwd) {
                lock.lock()
                cache[pid] = name
                lock.unlock()
                return name
            }
        }

        // Fallback 2: resolve from executable path (e.g. venv/bin/python, or node in project dir).
        if let exePath = getExecutablePath(for: pid) {
            let exeDir = (exePath as NSString).deletingLastPathComponent
            if let name = findProjectName(startingAt: exeDir) {
                lock.lock()
                cache[pid] = name
                lock.unlock()
                return name
            }
        }

        // Fallback 3: child process (e.g. Tor, worker) may have CWD=/ or system executable;
        // the parent that launched it often has CWD = project dir (e.g. situation).
        if let parentPid = getParentPID(pid), parentPid != 1, parentPid != pid {
            if let parentCwd = getCWD(for: parentPid),
               let name = findProjectName(startingAt: parentCwd) {
                lock.lock()
                cache[pid] = name
                lock.unlock()
                return name
            }
        }

        return nil
    }

    public func invalidateCache(for pids: Set<Int32>) {
        lock.lock()
        for pid in pids {
            cache.removeValue(forKey: pid)
        }
        lock.unlock()
    }

    private func getCWD(for pid: Int32) -> String? {
        let output = ShellExecutor.run("/usr/sbin/lsof -a -p \(pid) -d cwd -Fn 2>/dev/null")
        guard let output else { return nil }
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("n/") {
                return String(line.dropFirst())
            }
        }
        return nil
    }

    /// Parent process ID. Used when this process was launched by a script in the project (e.g. Tor, Vite worker).
    private func getParentPID(_ pid: Int32) -> Int32? {
        guard let output = ShellExecutor.run("/bin/ps -o ppid= -p \(pid) 2>/dev/null") else { return nil }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ppid = Int32(trimmed) else { return nil }
        return ppid > 0 ? ppid : nil
    }

    /// Executable path for the process (e.g. /usr/bin/node or .../venv/bin/python). Used when CWD doesn't yield a project.
    private func getExecutablePath(for pid: Int32) -> String? {
        guard let output = ShellExecutor.run("/usr/sbin/lsof -p \(pid) 2>/dev/null") else { return nil }
        let lines = output.components(separatedBy: "\n")
        for line in lines.dropFirst() {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            // COMMAND PID USER FD TYPE ... NAME; FD "txt" is the program executable
            guard parts.count >= 9, parts[3] == "txt" else { continue }
            let name = parts.dropFirst(8).joined(separator: " ")
            guard !name.isEmpty else { continue }
            return name
        }
        return nil
    }

    func findProjectName(startingAt path: String) -> String? {
        var current = path
        let fm = FileManager.default

        for _ in 0..<10 {
            if let name = readPackageJSON(at: current) { return name }
            if let name = readCargoToml(at: current) { return name }
            if let name = readGoMod(at: current) { return name }
            if let name = readPyproject(at: current) { return name }

            if fm.fileExists(atPath: (current as NSString).appendingPathComponent(".git")) {
                return URL(fileURLWithPath: current).lastPathComponent
            }

            let parent = (current as NSString).deletingLastPathComponent
            if parent == current { break }
            current = parent
        }

        let name = URL(fileURLWithPath: path).lastPathComponent
        return (name.isEmpty || name == "/") ? nil : name
    }

    private func readPackageJSON(at dir: String) -> String? {
        let file = (dir as NSString).appendingPathComponent("package.json")
        guard let data = FileManager.default.contents(atPath: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              !name.isEmpty
        else { return nil }
        return name
    }

    private func readCargoToml(at dir: String) -> String? {
        let file = (dir as NSString).appendingPathComponent("Cargo.toml")
        guard let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }
        // Simple parse: look for name = "..." under [package]
        var inPackage = false
        for line in contents.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[package]" { inPackage = true; continue }
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") { inPackage = false; continue }
            if inPackage, trimmed.hasPrefix("name") {
                return extractTomlValue(from: trimmed)
            }
        }
        return nil
    }

    private func readGoMod(at dir: String) -> String? {
        let file = (dir as NSString).appendingPathComponent("go.mod")
        guard let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }
        // First line: module github.com/user/project
        if let first = contents.components(separatedBy: "\n").first,
           first.hasPrefix("module ") {
            let modulePath = String(first.dropFirst("module ".count)).trimmingCharacters(in: .whitespaces)
            return URL(fileURLWithPath: modulePath).lastPathComponent
        }
        return nil
    }

    private func readPyproject(at dir: String) -> String? {
        let file = (dir as NSString).appendingPathComponent("pyproject.toml")
        guard let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }
        var inProject = false
        for line in contents.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[project]" || trimmed == "[tool.poetry]" { inProject = true; continue }
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") { inProject = false; continue }
            if inProject, trimmed.hasPrefix("name") {
                return extractTomlValue(from: trimmed)
            }
        }
        return nil
    }

    private func extractTomlValue(from line: String) -> String? {
        guard let eqIndex = line.firstIndex(of: "=") else { return nil }
        var value = String(line[line.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return value.isEmpty ? nil : value
    }
}
