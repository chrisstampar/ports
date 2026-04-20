import Foundation

public struct PortInfo: Identifiable, Equatable, Hashable {
    public let port: Int
    public let pid: Int32
    public let processName: String
    public var projectName: String?
    public var status: Status
    public var label: String?

    public var id: Int { port }

    public var displayName: String {
        label ?? projectName ?? processName
    }

    /// Name to show next to the port number. Never "/" or empty so the row never shows "port /".
    public var displayNameForRow: String {
        let name = displayName
        if name.isEmpty || name == "/" { return processName.isEmpty || processName == "/" ? "—" : processName }
        return name
    }

    public enum Status: String, Equatable, Hashable, CaseIterable {
        case unknown
        case healthy
        case slow
        case error
    }

    public init(
        port: Int,
        pid: Int32,
        processName: String,
        projectName: String? = nil,
        status: Status = .unknown,
        label: String? = nil
    ) {
        self.port = port
        self.pid = pid
        self.processName = processName
        self.projectName = projectName
        self.status = status
        self.label = label
    }
}
