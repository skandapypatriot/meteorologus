import Foundation

/// Mirrors the Flutter `OwnedDevice` model.
/// Represents a device claimed by the authenticated user.
struct OwnedDevice: Identifiable, Equatable {
    let mac: String
    let token: String?
    let claimedAt: Int?

    var id: String { mac }

    init(mac: String, token: String? = nil, claimedAt: Int? = nil) {
        self.mac = mac
        self.token = token
        self.claimedAt = claimedAt
    }

    var formattedMac: String {
        if mac.count == 12 {
            var parts: [String] = []
            var i = mac.startIndex
            while i < mac.endIndex {
                let next = mac.index(i, offsetBy: 2)
                parts.append(mac[i..<next].uppercased())
                i = next
            }
            return parts.joined(separator: ":")
        }
        return mac.uppercased()
    }

    static func == (lhs: OwnedDevice, rhs: OwnedDevice) -> Bool {
        lhs.mac == rhs.mac
    }

    /// Parses a single device from Firebase RTDB user-owned_devices node.
    static func fromMap(mac: String, data: Any?) -> OwnedDevice {
        guard let map = data as? [String: Any] else {
            return OwnedDevice(mac: mac)
        }
        return OwnedDevice(
            mac: mac,
            token: map["token"] as? String,
            claimedAt: {
                if let n = map["claimed_at"] as? NSNumber { return n.intValue }
                if let s = map["claimed_at"] as? String    { return Int(s) }
                return nil
            }()
        )
    }
}