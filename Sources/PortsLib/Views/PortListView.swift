import SwiftUI
import AppKit

public struct PortListView: View {
    @ObservedObject var service: PortMonitorService
    @State private var showSettings = false
    @State private var labelEditPort: PortInfo?
    @State private var labelText = ""

    public init(service: PortMonitorService) {
        self.service = service
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let error = service.scanError {
                errorView(error)
            } else if service.ports.isEmpty {
                EmptyStateView()
            } else {
                portList
            }

            Divider()
            footer
        }
        .frame(width: 280)
        .preferredColorScheme(.dark)
        .sheet(item: $labelEditPort) { port in
            labelEditor(for: port)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "network")
                .foregroundColor(.accentColor)
            Text("Ports")
                .font(.headline)
            Spacer()
            if service.isScanning {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.yellow)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Retry") { service.refresh() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var portList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(service.ports) { port in
                    PortRowView(
                        portInfo: port,
                        onOpenBrowser: { openInBrowser(port: port.port) },
                        onCopyURL: { copyURL(port: port.port) },
                        onKill: { showKillConfirmation(for: port) },
                        onEditLabel: {
                            labelText = port.label ?? ""
                            labelEditPort = port
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 360)
    }

    private var footer: some View {
        HStack {
            Text("\(service.ports.count) port\(service.ports.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: { service.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Refresh")
            .accessibilityLabel("Refresh")

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
            .popover(isPresented: $showSettings) {
                SettingsView(settings: service.settings)
            }

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Quit Ports")
            .accessibilityLabel("Quit Ports")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func labelEditor(for port: PortInfo) -> some View {
        VStack(spacing: 12) {
            Text(verbatim: "Label for \(port.port)")
                .font(.headline)
            TextField("Custom label", text: $labelText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            HStack {
                if !labelText.isEmpty {
                    Button("Remove") {
                        service.settings.portLabels.removeValue(forKey: port.port)
                        labelEditPort = nil
                        service.refresh()
                    }
                }
                Spacer()
                Button("Cancel") { labelEditPort = nil }
                Button("Save") {
                    let trimmed = labelText.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        service.settings.portLabels.removeValue(forKey: port.port)
                    } else {
                        service.settings.portLabels[port.port] = trimmed
                    }
                    labelEditPort = nil
                    service.refresh()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .preferredColorScheme(.dark)
    }

    private func openInBrowser(port: Int) {
        if let url = URL(string: "http://localhost:\(port)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyURL(port: Int) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("localhost:\(port)", forType: .string)
    }

    /// NSAlert after the popover closes. LSUIElement apps must activate or the sheet is not clickable.
    private func showKillConfirmation(for port: PortInfo) {
        let pid = port.pid
        let portNum = port.port
        let processName = port.processName
        let monitor = service

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let previousPolicy = NSApp.activationPolicy()
            // Menubar-only (LSUIElement) apps often need .regular briefly or NSAlert is not clickable.
            if previousPolicy != .regular {
                NSApp.setActivationPolicy(.regular)
            }
            NSApp.activate(ignoringOtherApps: true)
            NSApp.unhide(nil)

            let alert = NSAlert()
            alert.messageText = "Kill Process?"
            alert.informativeText = "Stop \(processName) on port \(portNum)? If it doesn’t exit quickly, it will be force quit."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Kill").keyEquivalent = "\r"
            alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1B}"
            let response = alert.runModal()

            if previousPolicy != .regular {
                NSApp.setActivationPolicy(previousPolicy)
            }

            if response == .alertFirstButtonReturn {
                _ = monitor.killProcess(pid: pid)
                // Refresh soon (fast quitters) and after SIGKILL escalation window.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { monitor.refresh() }
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.killEscalateDelay + 0.35) {
                    monitor.refresh()
                }
            }
        }
    }
}
