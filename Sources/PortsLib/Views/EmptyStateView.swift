import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No Active Ports")
                .font(.headline)
                .foregroundColor(.primary)
            Text("No localhost services detected.\nStart a dev server to see it here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No active ports. No localhost services detected. Start a dev server to see it here.")
    }
}
