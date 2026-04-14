import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var showVtKey = false

    var body: some View {
        Form {
            // DAEMON PATHS
            Section {
                LabeledContent("Watch path") {
                    TextField("~/Downloads", text: $store.watchPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }
                LabeledContent("Quarantine path") {
                    TextField("~/quarantine", text: $store.quarantinePath)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }
                LabeledContent("Database path") {
                    TextField("./data/jobs.sqlite", text: $store.databasePath)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }
            } header: {
                Text("PATHS").font(.caption).foregroundColor(.secondary)
            }

            // NETWORK
            Section {
                LabeledContent("HTTP port") {
                    TextField("3847", text: $store.httpPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                LabeledContent("HTTP host") {
                    TextField("127.0.0.1", text: $store.httpHost)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
            } header: {
                Text("NETWORK").font(.caption).foregroundColor(.secondary)
            }

            // VIRUSTOTAL
            Section {
                LabeledContent("API key") {
                    HStack {
                        if showVtKey {
                            TextField("Enter VT API key", text: $store.vtApiKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 280)
                        } else {
                            SecureField("Enter VT API key", text: $store.vtApiKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 280)
                        }
                        Button(action: { showVtKey.toggle() }) {
                            Image(systemName: showVtKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Get a free key at virustotal.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("VIRUSTOTAL").font(.caption).foregroundColor(.secondary)
            }

            // STATUS / SAVE
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
        .formStyle(.grouped)
        .frame(width: 520, height: 500)
        .onAppear { store.fetch() }
    }
}
