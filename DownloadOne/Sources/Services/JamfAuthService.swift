import Foundation

struct TokenResponse: Decodable {
    let access_token: String
    let expires_in: Int
}

actor JamfAuthService {
    private let baseURL = "https://wacmedev.jamfcloud.com"
    private let clientId: String
    private let clientSecret: String
    private var bearerToken: String?

    init(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    func authenticate() async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_secret", value: clientSecret),
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DownloadOneError.authenticationFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        bearerToken = tokenResponse.access_token
        return tokenResponse.access_token
    }

    func invalidate() async {
        guard let token = bearerToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/auth/invalidate-token")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        _ = try? await URLSession.shared.data(for: request)
        bearerToken = nil
    }
}

enum DownloadOneError: LocalizedError {
    case authenticationFailed
    case downloadFailed(String)
    case xmlParsingFailed
    case missingCredentials
    case itemNotFound(Int)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Failed to authenticate with Jamf Dev."
        case .downloadFailed(let detail):
            return "Download failed: \(detail)"
        case .xmlParsingFailed:
            return "Failed to parse the XML response."
        case .missingCredentials:
            return "DOWNLOADONE_CLIENT_ID and DOWNLOADONE_CLIENT_SECRET environment variables are required."
        case .itemNotFound(let id):
            return "Item with ID \(id) was not found."
        case .writeFailed(let detail):
            return "Failed to write files: \(detail)"
        }
    }
}
