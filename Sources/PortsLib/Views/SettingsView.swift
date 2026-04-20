import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var newExcludedPort = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            scanIntervalSection
            Divider()
            notificationsSection
            Divider()
            launchAtLoginSection
            Divider()
            excludedPortsSection
            Divider()
            aboutSection
        }
        .padding(16)
        .frame(width: 300)
        .preferredColorScheme(.dark)
    }

    private var scanIntervalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scan interval")
                .font(.subheadline)
                .fontWeight(.medium)
            HStack {
                Slider(
                    value: $settings.scanInterval,
                    in: Constants.minScanInterval...Constants.maxScanInterval,
                    step: 1
                )
                Text("\(Int(settings.scanInterval))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Notify when a port goes down", isOn: $settings.notificationsEnabled)
                .font(.subheadline)
                .onChange(of: settings.notificationsEnabled) { enabled in
                    if enabled {
                        NotificationService.shared.requestPermission()
                    }
                }
        }
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Open at login", isOn: $settings.launchAtLogin)
                .font(.subheadline)
                .onChange(of: settings.launchAtLogin) { enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        settings.launchAtLogin = !enabled
                    }
                }
        }
    }

    private var excludedPortsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Excluded ports")
                .font(.subheadline)
                .fontWeight(.medium)

            let userExcluded = settings.excludedPorts
                .subtracting(Constants.defaultExcludedPorts)
                .sorted()

            if !userExcluded.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(userExcluded, id: \.self) { port in
                        HStack(spacing: 4) {
                            Text(verbatim: "\(port)")
                                .font(.caption)
                            Button(action: { settings.excludedPorts = settings.excludedPorts.subtracting([port]) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("Port", text: $newExcludedPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit { addExcludedPort() }
                Button("Add") { addExcludedPort() }
                    .controlSize(.small)
                    .disabled(Int(newExcludedPort) == nil)
            }

            Text("System ports (5000, 7000, 49152+) are hidden by default.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var aboutSection: some View {
        HStack {
            Text("Ports v\(Constants.appVersion)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func addExcludedPort() {
        guard let port = Int(newExcludedPort), port > 0, port <= 65535 else { return }
        settings.excludedPorts = settings.excludedPorts.union([port])
        newExcludedPort = ""
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
