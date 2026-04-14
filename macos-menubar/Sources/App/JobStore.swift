import Foundation

struct SandboxJob: Codable, Identifiable {
    let id: String
    let original_name: String
    let status: String
    let vt_verdict: String?
    let detail: String?
    let final_path: String?
    let created_at: Int
}

struct JobsResponse: Codable {
    let jobs: [SandboxJob]
}

enum ClientAuthStorage {
    private static let key = "filesandboxClientAPIToken"
    static var token: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

class JobStore: ObservableObject {
    @Published var jobs: [SandboxJob] = []
    @Published var isConnected = false
    @Published var lastActionError: String? = nil

    private var timer: Timer?
    private let apiURL: URL

    private let port: String

    init() {
        self.port = ProcessInfo.processInfo.environment["FILE_SANDBOX_PORT"] ?? "3847"
        self.apiURL = URL(string: "http://127.0.0.1:\(self.port)/api/jobs")!
        startPolling()
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        let t = ClientAuthStorage.token
        if !t.isEmpty {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    var activeThreats: [SandboxJob] {
        jobs.filter { $0.vt_verdict == "infected" && $0.status == "quarantine_kept" }
    }

    var iconName: String {
        guard isConnected else { return "shield.slash" }
        if !activeThreats.isEmpty {
            return "exclamationmark.shield.fill"
        }
        if jobs.contains(where: { $0.status == "scanning" || $0.status == "in_quarantine" }) {
            return "shield.lefthalf.filled"
        }
        return "checkmark.shield.fill"
    }

    var threatCount: Int { activeThreats.count }

    func startPolling() {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func clearJobs() {
        var request = authorizedRequest(url: apiURL)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.lastActionError = "Network error: \(error.localizedDescription)"
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    self.lastActionError = "Request failed (\(httpResponse.statusCode))"
                    return
                }
                self.lastActionError = nil
                self.fetch()
            }
        }.resume()
    }

    func cancelJob(_ id: String) {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/jobs/\(id)/cancel") else { return }
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.lastActionError = "Network error: \(error.localizedDescription)"
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    self.lastActionError = "Request failed (\(httpResponse.statusCode))"
                    return
                }
                self.lastActionError = nil
                self.fetch()
            }
        }.resume()
    }

    func deleteFile(_ id: String) {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/jobs/\(id)/quarantine") else { return }
        var request = authorizedRequest(url: url)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.lastActionError = "Network error: \(error.localizedDescription)"
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    self.lastActionError = "Request failed (\(httpResponse.statusCode))"
                    return
                }
                self.lastActionError = nil
                self.fetch()
            }
        }.resume()
    }

    func restoreFile(_ id: String) {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/jobs/\(id)/restore") else { return }
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.lastActionError = "Network error: \(error.localizedDescription)"
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    self.lastActionError = "Request failed (\(httpResponse.statusCode))"
                    return
                }
                self.lastActionError = nil
                self.fetch()
            }
        }.resume()
    }

    func fetch() {
        let request = authorizedRequest(url: apiURL)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard error == nil, let data else {
                    self.isConnected = false
                    return
                }
                guard let decoded = try? JSONDecoder().decode(JobsResponse.self, from: data) else {
                    self.isConnected = false
                    return
                }
                self.isConnected = true
                self.jobs = decoded.jobs
            }
        }.resume()
    }
}
