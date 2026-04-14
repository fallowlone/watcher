import SwiftUI

private struct OptionalWidth: ViewModifier {
    var width: CGFloat?

    func body(content: Content) -> some View {
        Group {
            if let w = width {
                content.frame(width: w)
            } else {
                content.frame(maxWidth: .infinity)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var showVtKey = false

    private var inconclusiveEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.inconclusiveRetentionDays > 0 },
            set: { on in
                if on {
                    if store.inconclusiveRetentionDays < 1 {
                        store.inconclusiveRetentionDays = 7
                    }
                } else {
                    store.inconclusiveRetentionDays = 0
                }
            }
        )
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            watchScanTab
                .tabItem { Label("Watch & scan", systemImage: "folder.badge.gearshape") }
        }
        .frame(minWidth: 400, idealWidth: 420, maxWidth: 460, minHeight: 480)
        .onAppear { store.fetch() }
    }

    private var generalTab: some View {
        ScrollView {
            Form {
                Section {
                    stackedTextField(
                        title: "Watch path",
                        text: $store.watchPath,
                        prompt: "/Users/you/Downloads"
                    )
                    stackedTextField(
                        title: "Quarantine path",
                        text: $store.quarantinePath,
                        prompt: "/Users/you/.file-sandbox/quarantine"
                    )
                    stackedTextField(
                        title: "Database path",
                        text: $store.databasePath,
                        prompt: "./data/jobs.sqlite"
                    )
                    Text("Prompts show only when the field is empty; they are not saved.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } header: {
                    Text("PATHS").font(.caption).foregroundColor(.secondary)
                }

                Section {
                    HStack(spacing: 16) {
                        HStack(spacing: 8) {
                            fieldLabel("Port")
                            TextField("", text: $store.httpPort,
                                      prompt: Text("3847").foregroundStyle(.tertiary))
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(width: 72)
                        }
                        HStack(spacing: 8) {
                            fieldLabel("Host")
                            TextField("", text: $store.httpHost,
                                      prompt: Text("127.0.0.1").foregroundStyle(.tertiary))
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    stackedSecureField(
                        title: "API token",
                        text: $store.apiAuthToken,
                        prompt: "optional"
                    )

                    Text("If set, sent as Authorization: Bearer. Matches `apiToken` in config.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("NETWORK").font(.caption).foregroundColor(.secondary)
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        fieldLabel("VirusTotal API key")
                        HStack(spacing: 8) {
                            Group {
                                if showVtKey {
                                    TextField("", text: $store.vtApiKey, prompt: promptKeyHint)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("", text: $store.vtApiKey, prompt: promptKeyHint)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Button(action: { showVtKey.toggle() }) {
                                Image(systemName: showVtKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Free key at virustotal.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("VIRUSTOTAL").font(.caption).foregroundColor(.secondary)
                }

                saveSection
            }
            .formStyle(.grouped)
            .padding(.bottom, 12)
        }
    }

    private var promptKeyHint: Text {
        Text("Paste key from virustotal.com").foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func stackedTextField(
        title: String,
        text: Binding<String>,
        prompt: String,
        fieldWidth: CGFloat? = nil,
        expandRow: Bool = true
    ) -> some View {
        let inner = VStack(alignment: .leading, spacing: 4) {
            fieldLabel(title)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(.tertiary))
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)
                .multilineTextAlignment(fieldWidth != nil ? .trailing : .leading)
                .modifier(OptionalWidth(width: fieldWidth))
        }
        if expandRow {
            inner.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            inner.fixedSize(horizontal: true, vertical: false)
        }
    }

    private func stackedSecureField(
        title: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(title)
            SecureField("", text: text, prompt: Text(prompt).foregroundStyle(.tertiary))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.medium))
    }

    private var watchScanTab: some View {
        ScrollView {
            Form {
                Section {
                    Toggle("Watch subfolders", isOn: $store.watchRecursive)
                    Text("Off = only files directly inside the watch folder (`watchRecursive`).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("WATCH").font(.caption).foregroundColor(.secondary)
                }

                Section {
                    rowLabel("Max scan size") {
                        HStack(spacing: 12) {
                            Stepper(
                                value: $store.maxScanMegabytes,
                                in: 1...8192,
                                step: 1
                            ) {
                                Text("\(store.maxScanMegabytes) MB")
                                    .monospacedDigit()
                                    .frame(minWidth: 72, alignment: .trailing)
                            }
                        }
                    }
                    rowLabel("Concurrent scans") {
                        Stepper(
                            value: $store.maxConcurrentScans,
                            in: 1...16,
                            step: 1
                        ) {
                            Text("\(store.maxConcurrentScans)")
                                .monospacedDigit()
                                .frame(minWidth: 24, alignment: .trailing)
                        }
                    }
                    Toggle("VirusTotal in child process", isOn: $store.useSeparateVtProcess)
                    Text("Stored as `maxScanBytes` (MiB×1024²), `maxConcurrentScans`, `useSeparateVtProcess`.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("VIRUSTOTAL LIMITS").font(.caption).foregroundColor(.secondary)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Auto-remove inconclusive files", isOn: inconclusiveEnabledBinding)

                        if store.inconclusiveRetentionDays > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Delete after")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(store.inconclusiveRetentionDays) days")
                                        .monospacedDigit()
                                        .font(.body.weight(.medium))
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(store.inconclusiveRetentionDays) },
                                        set: { store.inconclusiveRetentionDays = max(1, min(365, Int($0.rounded()))) }
                                    ),
                                    in: 1...365,
                                    step: 1
                                )
                                HStack(spacing: 8) {
                                    quickDayButton(7)
                                    quickDayButton(14)
                                    quickDayButton(30)
                                    quickDayButton(90)
                                }
                            }
                        } else {
                            Text("Inconclusive items stay until you delete them.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)

                    Text("`inconclusiveRetentionDays` — hourly purge on the daemon.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } header: {
                    Text("INCONCLUSIVE QUARANTINE").font(.caption).foregroundColor(.secondary)
                }

                saveSection
            }
            .formStyle(.grouped)
            .padding(.bottom, 12)
        }
    }

    private func quickDayButton(_ days: Int) -> some View {
        let on = store.inconclusiveRetentionDays == days
        return Button {
            store.inconclusiveRetentionDays = days
        } label: {
            Text("\(days)d")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(on ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }

    /// Avoids `LabeledContent` + control duplication in grouped Form on macOS.
    @ViewBuilder
    private func rowLabel<V: View>(_ title: String, @ViewBuilder content: () -> V) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .frame(width: 132, alignment: .leading)
            content()
        }
    }

    private var saveSection: some View {
        Section {
            HStack {
                if store.isLoading {
                    ProgressView().controlSize(.small)
                    Text("Loading…").foregroundColor(.secondary).font(.caption)
                } else if let result = store.saveResult {
                    if result == "ok" {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Saved — restart daemon to apply")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        Text(result.replacingOccurrences(of: "err:", with: ""))
                            .font(.caption).foregroundColor(.red)
                    }
                } else if let err = store.loadError {
                    Image(systemName: "wifi.exclamationmark").foregroundColor(.orange)
                    Text(err).font(.caption).foregroundColor(.orange)
                }
                Spacer()
                Button("Save") { store.save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isSaving || store.isLoading)
            }
        }
    }
}
