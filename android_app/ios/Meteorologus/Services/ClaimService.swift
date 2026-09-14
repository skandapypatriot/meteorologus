import Foundation

/// Claims a weather node for the current user.
/// Mirrors `android_app/lib/services/claim_service.dart`.
final class ClaimService {

    enum ClaimError: LocalizedError {
        case invalidMac

        var errorDescription: String? {
            switch self {
            case .invalidMac:
                return "Invalid MAC address. Must be 12 hexadecimal characters."
            }
        }
    }

    private let baseURL = FirebaseConfig.databaseURL

    /// Removes `-`, `:` and whitespace, uppercases the remainder.
    static func normalizeMac(_ input: String) -> String {
        input.replacingOccurrences(of: "[:\\- ]", with: "", options: .regularExpression)
            .uppercased()
    }

    static func isValidMac(_ input: String) -> Bool {
        let clean = normalizeMac(input)
        guard clean.count == 12 else { return false }
        return clean.range(of: "^[0-9A-F]{12}$", options: .regularExpression) != nil
    }

    func isDeviceClaimed(mac: String, authToken: String) async throws -> Bool {
        let clean = ClaimService.normalizeMac(mac)
        guard let url = URL(string: "\(baseURL)/claimed_devices/\(clean).json?auth=\(authToken)") else {
            return false
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return !data.isEmpty && data != Data("null".utf8)
    }

    func claimDevice(uid: String, mac: String, authToken: String) async throws {
        let clean = ClaimService.normalizeMac(mac)
        guard ClaimService.isValidMac(clean) else {
            throw ClaimError.invalidMac
        }

        let token = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        let now = Int(Date().timeIntervalSince1970 * 1000)

        try await put(path: "claimed_devices/\(clean)", value: token, authToken: authToken)
        try await put(
            path: "users/\(uid)/owned_devices/\(clean)",
            value: ["token": token, "claimed_at": now],
            authToken: authToken
        )
    }

    // MARK: - Private

    private func put(path: String, value: Any, authToken: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(path).json?auth=\(authToken)") else {
            throw DatabaseError.api("Invalid database URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let stringValue = value as? String {
            request.httpBody = try JSONEncoder().encode(stringValue)
        } else {
            request.httpBody = try JSONSerialization.data(withJSONObject: value)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw DatabaseError.api("Network request failed.")
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DatabaseError.api(msg)
        }
    }
}