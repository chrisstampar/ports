import Foundation

public enum Constants {
    public static let defaultScanInterval: TimeInterval = 5.0
    public static let minScanInterval: TimeInterval = 1.0
    public static let maxScanInterval: TimeInterval = 60.0

    public static let defaultExcludedPorts: Set<Int> = {
        var ports: Set<Int> = [5000, 7000]
        ports.formUnion(Set(49152...65535))
        return ports
    }()

    public static let excludedProcessNames: Set<String> = [
        "rapportd",
        "ControlCenter",
        "ControlCe",
        "sharingd",
        "AirPlayXPCHelper",
        "WiFiAgent",
    ]

    public static let healthCheckTimeout: TimeInterval = 3.0
    public static let healthCheckSlowThreshold: TimeInterval = 2.0

    /// Max time a shell command (e.g. lsof) may run before being terminated.
    public static let shellCommandTimeout: TimeInterval = 15.0

    /// After SIGTERM, wait this long; if the process is still running, send SIGKILL.
    public static let killEscalateDelay: TimeInterval = 0.75

    public static let appVersion: String = "1.0.0"
}
