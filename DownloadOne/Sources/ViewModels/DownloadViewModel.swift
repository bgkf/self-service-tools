import SwiftUI
import SystemConfiguration

enum AppState: Equatable {
    case input
    case authenticating
    case downloading
    case writing
    case success(name: String, path: String)
    case failure(message: String)

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.input, .input),
             (.authenticating, .authenticating),
             (.downloading, .downloading),
             (.writing, .writing):
            return true
        case (.success(let a, _), .success(let b, _)):
            return a == b
        case (.failure(let a), .failure(let b)):
            return a == b
        default:
            return false
        }
    }
}

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var state: AppState = .input
    @Published var selectedType: ItemType = .script
    @Published var itemIdText: String = ""
    @Published var statusMessage: String = ""

    private let clientId: String
    private let clientSecret: String
    private var authService: JamfAuthService?
    private let downloadService = JamfDownloadService()
    private let fileWriter = FileWriterService()

    var resultOutputURL: URL?

    var loggedInUser: String {
        var uid: uid_t = 0
        let user = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as String?
        return user ?? "unknown"
    }

    init() {
        let env = ProcessInfo.processInfo.environment
        self.clientId = env["DOWNLOADONE_CLIENT_ID"] ?? ""
        self.clientSecret = env["DOWNLOADONE_CLIENT_SECRET"] ?? ""
        NSLog("DownloadOne: credentials loaded via env (clientId present: \(!clientId.isEmpty))")
    }

    func startDownload() async {
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            state = .failure(message: DownloadOneError.missingCredentials.localizedDescription)
            return
        }

        guard let id = Int(itemIdText.trimmingCharacters(in: .whitespaces)), id > 0 else {
            state = .failure(message: "Please enter a valid numeric ID.")
            return
        }

        let auth = JamfAuthService(clientId: clientId, clientSecret: clientSecret)
        authService = auth

        defer {
            Task { await auth.invalidate() }
        }

        do {
            state = .authenticating
            statusMessage = "Authenticating with Jamf Dev…"
            let token = try await auth.authenticate()

            state = .downloading
            statusMessage = "Downloading \(selectedType.rawValue) \(id)…"
            let result = try await downloadService.download(itemType: selectedType, id: id, token: token)

            state = .writing
            statusMessage = "Writing files to /Users/Shared/\(result.name)/…"
            try fileWriter.write(result: result, loggedInUser: loggedInUser)

            resultOutputURL = result.outputURL
            state = .success(name: result.name, path: result.outputURL.path)
        } catch {
            state = .failure(message: error.localizedDescription)
        }
    }

    func reset() {
        state = .input
        itemIdText = ""
        statusMessage = ""
        resultOutputURL = nil
    }
}
