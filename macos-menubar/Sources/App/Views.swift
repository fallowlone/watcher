import SwiftUI

struct JobRowView: View {
    let job: SandboxJob
    let onCancel: () -> Void

    var statusIcon: (name: String, color: Color) {
        switch job.status {
        case "restored":        return ("checkmark.circle.fill", .green)
        case "quarantine_kept": return ("xmark.shield.fill", .red)
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
        case "quarantine_kept": return "Infected — quarantined"
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
            } else if let verdict = job.vt_verdict {
                Text(verdict)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(verdict == "clean"
                        ? Color.green.opacity(0.15)
                        : Color.red.opacity(0.15))
                    .foregroundColor(verdict == "clean" ? .green : .red)
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
        .onChange(of: isScanning) { scanning in
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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            jobList
            Divider()
            footer
        }
        .frame(width: 420)
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
                        JobRowView(job: job, onCancel: { store.cancelJob(job.id) })
                        if job.id != visible.last?.id {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
            }
            .frame(minHeight: 80, maxHeight: 500)
        }
    }

    private var footer: some View {
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
