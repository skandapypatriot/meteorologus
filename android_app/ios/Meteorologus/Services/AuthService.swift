import Foundation

/// Represents a signed-in user session returned by the Firebase Auth REST API.
struct StoredSession: Codable, Equatable {
    let uid: String
    let email: String
    let idToken: String
    let refreshToken: String

    func encodedData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func fromData(_ data: Data) -> StoredSession? {
        try? JSONDecoder().decode(StoredSession.self, from: data)
    }
}

enum AuthServiceError: LocalizedError {
    case invalidResponse
    case api(String)
    case network

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected server response."
        case .api(let message):
            return message
        case .network:
            return "Network request failed. Check your connection."
        }
    }
}

/// Wraps the Firebase Auth REST API (`identitytoolkit.googleapis.com`).
/// Mirrors `android_app/lib/services/auth_service.dart`.
final class AuthService {

    private let baseURL = "\(FirebaseConfig.identityToolkitURL)/accounts"

    func signUp(email: String, password: String) async throws -> StoredSession {
        let body: [String: Any] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password,
            "returnSecureToken": true,
        ]
        return try await perform(method: "signUp", body: body)
    }

    func signIn(email: String, password: String) async throws -> StoredSession {
        let body: [String: Any] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password,
            "returnSecureToken": true,
        ]
        return try await perform(method: "signInWithPassword", body: body)
    }

    func sendPasswordReset(email: String) async throws {
        let body: [String: Any] = [
            "requestType": "PASSWORD_RESET",
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        _ = try await perform(method: "sendOobCode", body: body)
    }

    func exchangeRefreshToken(_ refreshToken: String) async throws -> StoredSession? {
        guard let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)") else {
            throw AuthServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ])

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let map = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthServiceError.invalidResponse
        }
        guard
            let idToken = map["id_token"] as? String,
            let refreshToken = map["refresh_token"] as? String,
            let uid = map["user_id"] as? String
        else {
            return nil
        }
        let email = map["email"] as? String ?? ""
        return StoredSession(uid: uid, email: email, idToken: idToken, refreshToken: refreshToken)
    }

    // MARK: - Private

    private func perform(method: String, body: [String: Any]) async throws -> StoredSession {
        guard let url = URL(string: "\(baseURL):\(method)?key=\(FirebaseConfig.apiKey)") else {
            throw AuthServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthServiceError.network
        }

        guard let map = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthServiceError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let msg = (map["error"] as? [String: Any])?["message"] as? String
            throw AuthServiceError.api(msg ?? "Authentication failed (HTTP \(http.statusCode)).")
        }

        guard
            let idToken = map["idToken"] as? String,
            let refreshToken = map["refreshToken"] as? String,
            let uid = map["localId"] as? String
        else {
            throw AuthServiceError.invalidResponse
        }

        let email = map["email"] as? String ?? ""
        return StoredSession(uid: uid, email: email, idToken: idToken, refreshToken: refreshToken)
    }
}