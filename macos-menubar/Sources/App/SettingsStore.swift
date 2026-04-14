import Foundation

struct DaemonConfig: Codable {
    var vtApiKey: String
    var watchPath: String
    var quarantinePath: String
    var databasePath: String
    var httpPort: String
    var httpHost: String
}

class SettingsStore: ObservableObject {
    @Published var vtApiKey: String = ""
    @Published var watchPath: String = ""
    @Published var quarantinePath: String = ""
    @Published var databasePath: String = ""
    @Published var httpPort: String = ""
    @Published var httpHost: String = ""

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var saveResult: String? = nil   // nil = idle, "ok" = success, "err:…" = error
    @Published var loadError: String? = nil

    private let port: String

    init() {
        self.port = ProcessInfo.processInfo.environment["FILE_SANDBOX_PORT"] ?? "3847"
    }

    func fetch() {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/config") else { return }
        isLoading = true
        loadError = nil
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                guard error == nil, let data,
                      let decoded = try? JSONDecoder().decode(DaemonConfig.self, from: data)
                else {
                    self.loadError = error?.localizedDescription ?? "Failed to load config"
                    return
                }
                self.vtApiKey = decoded.vtApiKey
                self.watchPath = decoded.watchPath
                self.quarantinePath = decoded.quarantinePath
                self.databasePath = decoded.databasePath
                self.httpPort = decoded.httpPort
                self.httpHost = decoded.httpHost
            }
        }.resume()
    }

    func save() {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/config") else { return }
        isSaving = true
        saveResult = nil

        let body: [String: String] = [
            "vtApiKey": vtApiKey,
            "watchPath": watchPath,
            "quarantinePath": quarantinePath,
            "databasePath": databasePath,
            "httpPort": httpPort,
            "httpHost": httpHost,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false
                if let error {
                    self.saveResult = "err:\(error.localizedDescription)"
                    return
                }
                self.saveResult = "ok"
                // Auto-clear success banner after 3s
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.saveResult == "ok" { self.saveResult = nil }
                }
            }
        }.resume()
    }
}
