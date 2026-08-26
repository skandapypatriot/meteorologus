class OwnedDevice {
  final String mac;
  final String? token;
  final int? claimedAt;

  const OwnedDevice({
    required this.mac,
    this.token,
    this.claimedAt,
  });

  factory OwnedDevice.fromMap(String mac, dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
      return OwnedDevice(
        mac: mac,
        token: map['token']?.toString(),
        claimedAt: int.tryParse(map['claimed_at']?.toString() ?? ''),
      );
    }
    return OwnedDevice(mac: mac);
  }

  String get formattedMac {
    if (mac.length == 12) {
      final parts = <String>[];
      for (int i = 0; i < 12; i += 2) {
        parts.add(mac.substring(i, i + 2));
      }
      return parts.join(':').toUpperCase();
    }
    return mac.toUpperCase();
  }
}
