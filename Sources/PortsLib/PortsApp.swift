import SwiftUI

public struct PortsApp: App {
    @StateObject private var service = PortMonitorService()

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            PortListView(service: service)
                .onAppear { service.startMonitoring() }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "network")
                if !service.ports.isEmpty {
                    Text("\(service.ports.count)")
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
