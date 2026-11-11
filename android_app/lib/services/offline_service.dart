import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/device_reading.dart';

/// Default IP of the ESP32 softAP hotspot.
const String kDefaultDeviceIp = 'http://192.168.4.1';
const int kOfflinePortalPort = 81;

class OfflineService {
  final http.Client _client;

  OfflineService({http.Client? client}) : _client = client ?? http.Client();

  /// Base URL for the device's offline portal (e.g. http://192.168.4.1:81).
  String baseUrl(String ip) {
    final cleaned = ip.trim();
    if (cleaned.isEmpty) return kDefaultDeviceIp;
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      return 'http://$cleaned';
    }
    return cleaned;
  }

  /// Fetch the latest prediction from the device.
  Future<DeviceReading?> fetchLatest(String ip) async {
    final url = Uri.parse('${baseUrl(ip)}:$kOfflinePortalPort/api/latest');
    try {
      final res = await _client.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return DeviceReading.fromJson(null, decoded);
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  /// Fetch all stored readings from the device (last 30 days).
  Future<List<DeviceReading>> fetchReadings(String ip) async {
    final url = Uri.parse('${baseUrl(ip)}:$kOfflinePortalPort/api/readings');
    try {
      final res = await _client.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded
              .map((e) => DeviceReading.fromJson(null, e))
              .toList()
            ..sort((a, b) => (a.ts ?? 0).compareTo(b.ts ?? 0));
        }
      }
    } catch (_) {
      // ignore
    }
    return [];
  }

  /// Ping the device to check if it's reachable on the hotspot.
  Future<bool> isReachable(String ip) async {
    try {
      final res = await _client
          .get(Uri.parse('${baseUrl(ip)}:$kOfflinePortalPort/'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
