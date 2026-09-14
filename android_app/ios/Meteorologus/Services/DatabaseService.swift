import Foundation

enum DatabaseError: LocalizedError {
    case unauthorized
    case api(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case .api(let message):
            return message
        }
    }
}

/// Access to the Firebase Realtime Database over REST.
/// Mirrors `android_app/lib/services/database_service.dart` (its REST fallback path).
/// Real-time "streams" are simulated by the view models polling `get...` periodically.
final class DatabaseService {

    private let baseURL = FirebaseConfig.databaseURL

    // MARK: - Owned devices

    func getOwnedDevices(uid: String, authToken: String) async throws -> [OwnedDevice] {
        let data = try await get(path: "users/\(uid)/owned_devices", authToken: authToken)
        guard let map = data as? [String: Any] else { return [] }
        return map.map { OwnedDevice.fromMap(mac: $0.key, data: $0.value) }
    }

    // MARK: - Device readings

    func getDeviceReadings(mac: String, authToken: String) async throws -> [DeviceReading] {
        let data = try await get(path: "devices/\(mac)", authToken: authToken)
        guard let map = data as? [String: Any] else { return [] }

        let readings = map.map { DeviceReading.fromJson($0.value, key: $0.key) }
        return readings.sorted { ($0.ts ?? 0) < ($1.ts ?? 0) }
    }

    // MARK: - Private

    private func get(path: String, authToken: String) async throws -> Any? {
        guard let url = URL(string: "\(baseURL)/\(path).json?auth=\(authToken)") else {
            throw DatabaseError.api("Invalid database URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw DatabaseError.api("Network request failed.")
        }

        if http.statusCode == 401 {
            throw DatabaseError.unauthorized
        }

        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DatabaseError.api(msg)
        }

        if data.isEmpty || data == Data("null".utf8) {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data)
    }
}