import SwiftUI

struct PortRowView: View {
    let portInfo: PortInfo
    let onOpenBrowser: () -> Void
    let onCopyURL: () -> Void
    let onKill: () -> Void
    let onEditLabel: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            statusDot

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    // Use verbatim so the port number is never formatted with locale thousands separators.
                    Text(verbatim: "\(portInfo.port)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(portInfo.displayNameForRow)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if portInfo.label != nil, let project = portInfo.projectName {
                    Text(project)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            Spacer()

            if isHovering {
                actionButtons
            } else {
                Text(portInfo.processName)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color.white.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch portInfo.status {
        case .healthy: return .green
        case .error: return .red
        case .slow: return .yellow
        case .unknown: return .gray
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            actionButton(icon: "safari", tooltip: "Open in browser", action: onOpenBrowser)
            actionButton(icon: "doc.on.doc", tooltip: "Copy URL", action: onCopyURL)
            actionButton(icon: "tag", tooltip: "Edit label", action: onEditLabel)
            actionButton(icon: "xmark.circle", tooltip: "Kill process", action: onKill)
                .foregroundColor(.red.opacity(0.8))
        }
    }

    private func actionButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}
