import SwiftUI
import AppKit

struct JobRowView: View {
    let job: SandboxJob
    let onCancel: () -> Void
    let onDelete: () -> Void
    let onRestore: () -> Void

    var statusIcon: (name: String, color: Color) {
        switch job.status {
        case "restored":        return ("checkmark.circle.fill", .green)
        case "quarantine_kept":
            if job.vt_verdict == "oversized" {
                return ("arrow.down.circle.fill", .orange)
            }
            return ("xmark.shield.fill", .red)
        case "cancelled":       return ("nosign", .secondary)
        case "scanning":        return ("magnifyingglass.circle.fill", .orange)
        case "in_quarantine":   return ("lock.shield.fill", .yellow)
        case "failed":          return ("exclamationmark.triangle.fill", .red)
        default:                return ("circle.dotted", .secondary)
        }
    }

    var displayStatus: String {
        switch job.status {
        case "restored":        return "Clean"
        case "quarantine_kept":
            if job.vt_verdict == "oversized" {
                return "Too large — quarantined (no VT scan)"
            }
            if job.vt_verdict == "inconclusive" {
                return "Unclear — in quarantine"
            }
            return "Infected — quarantined"
        case "deleted":         return "Deleted"
        case "cancelled":       return "Cancelled"
        case "scanning":        return "Scanning…"
        case "in_quarantine":   return "In quarantine"
        case "failed":          return "Failed"
        default:                return job.status.replacingOccurrences(of: "_", with: " ")
        }
    }

    var isScanning: Bool { job.status == "scanning" }

    @State private var glowOpacity: Double = 0.03
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: 10) {
            // Icon: native spinner while scanning, static icon otherwise
            Group {
                if isScanning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                } else {
                    Image(systemName: statusIcon.name)
                        .foregroundColor(statusIcon.color)
                }
            }
            .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.original_name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(displayStatus)
                    .font(.system(size: 11))
                    .foregroundColor(isScanning ? .orange : .secondary)
                    .animation(.easeInOut(duration: 0.3), value: isScanning)
            }

            Spacer()

            if isScanning {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel scan — keep file in sandbox")
            } else if job.status == "deleted" {
                // nothing — file gone
            } else if job.status == "quarantine_kept" {
                HStack(spacing: 6) {
                    if let verdict = job.vt_verdict {
                        Text(verdict)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                verdict == "oversized"
                                    ? Color.orange.opacity(0.2)
                                    : Color.red.opacity(0.15)
                            )
                            .foregroundColor(verdict == "oversized" ? .orange : .red)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Button(action: onRestore) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Restore to watch folder")
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Permanently delete quarantined file")
                }
            } else if let verdict = job.vt_verdict {
                Text(verdict)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background {
            if isScanning {
                ZStack {
                    // Pulsing orange glow
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(glowOpacity))

                    // Moving shimmer stripe
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.orange.opacity(0.12),
                                    .clear,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                        .clipped()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear { startAnimations() }
        .onChange(of: isScanning) { _, scanning in
            if scanning { startAnimations() }
        }
    }

    private func startAnimations() {
        guard isScanning else { return }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            glowOpacity = 0.11
        }
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
            shimmerOffset = 420
        }
    }
}

struct MenuBarContentView: View {
    @ObservedObject var store: JobStore
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            jobList
            Divider()
            footer
        }
        .frame(width: 420)
        .onAppear {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.checkmark.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 15))
            Text("FileSandbox")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Circle()
                .fill(store.isConnected ? Color.green : Color.red)
                .frame(width: 7, height: 7)
            Button(action: { store.fetch() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Refresh")

            if !store.jobs.isEmpty {
                Button(action: { store.clearJobs() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Clear all logs")
            }
            Button(action: {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var jobList: some View {
        if !store.isConnected {
            VStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 26))
                    .foregroundColor(.orange)
                Text("Cannot reach daemon")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else if store.jobs.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 26))
                    .foregroundColor(.secondary)
                Text("No files processed yet")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            let visible = Array(store.jobs.prefix(30))
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(visible) { job in
                        JobRowView(
                            job: job,
                            onCancel: { store.cancelJob(job.id) },
                            onDelete: { store.deleteFile(job.id) },
                            onRestore: { store.restoreFile(job.id) }
                        )
                        if job.id != visible.last?.id {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
            }
            .frame(minHeight: 160, maxHeight: 700)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if let error = store.lastActionError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .transition(.opacity)
            }
            HStack {
                if store.threatCount > 0 {
                    Label(
                        "\(store.threatCount) threat\(store.threatCount == 1 ? "" : "s")",
                        systemImage: "exclamationmark.shield.fill"
                    )
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
}
