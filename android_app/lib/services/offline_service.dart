import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import '../models/offline_device_data.dart';
import 'database_service.dart';

class OfflineService {
  static const String HOTSPOT_SSID_PREFIX = 'MeteoData-';
  static const String HOTSPOT_PASSWORD = 'weather123';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 10);
  static const Duration SCAN_INTERVAL = Duration(seconds: 5);

  final NetworkInfo _networkInfo = NetworkInfo();
  final DatabaseService _dbService = DatabaseService();
  
  Timer? _scanTimer;
  bool _isScanning = false;

  Future<HotspotInfo?> findHotspot() async {
    try {
      final wifiName = await _networkInfo.getWifiName();
      if (wifiName != null && wifiName.startsWith(HOTSPOT_SSID_PREFIX)) {
        final ip = await _networkInfo.getWifiGatewayIP();
        if (ip != null) {
          return HotspotInfo(
            ssid: wifiName,
            password: HOTSPOT_PASSWORD,
            ipAddress: ip,
          );
        }
      }
    } catch (e) {
      print('[OfflineService] Error finding hotspot: $e');
    }
    return null;
  }

  Future<OfflineDeviceData?> fetchDataFromHotspot(String ipAddress) async {
    try {
      final uri = Uri.parse('http://$ipAddress/api/data');
      final response = await http.get(uri).timeout(REQUEST_TIMEOUT);
      
      if (response.statusCode == 200) {
        return OfflineDeviceData.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (e) {
      print('[OfflineService] Error fetching data: $e');
    }
    return null;
  }

  Future<OfflineDeviceData?> connectAndFetch(String mac) async {
    print('[OfflineService] Looking for hotspot for device: $mac');
    
    // First check if we're already connected to the right hotspot
    final currentHotspot = await findHotspot();
    if (currentHotspot != null) {
      print('[OfflineService] Already connected to hotspot: ${currentHotspot.ssid}');
      return await fetchDataFromHotspot(currentHotspot.ipAddress);
    }

    // Try to find and connect to the hotspot
    // Note: On Android, we can't programmatically connect to WiFi without user interaction
    // We'll guide the user to connect manually
    return null;
  }

  Future<OfflineDeviceData?> fetchOfflineData(String deviceId) async {
    final hotspot = await findHotspot();
    if (hotspot == null) {
      return null;
    }
    return await fetchDataFromHotspot(hotspot.ipAddress);
  }

  void startAutoScan(String deviceId, Function(OfflineDeviceData) onData) {
    stopAutoScan();
    _isScanning = true;
    _scanTimer = Timer.periodic(SCAN_INTERVAL, (timer) async {
      if (!_isScanning) {
        timer.cancel();
        return;
      }
      final data = await fetchOfflineData(deviceId);
      if (data != null) {
        onData(data);
      }
    });
  }

  void stopAutoScan() {
    _isScanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  Future<void> saveOfflineReading(
    String uid,
    String mac,
    OfflineInferenceRecord record,
  ) async {
    await _dbService.saveOfflineReading(uid, mac, record);
  }

  Future<List<OfflineInferenceRecord>> getOfflineReadings(
    String uid,
    String mac,
  ) async {
    return await _dbService.getOfflineReadings(uid, mac);
  }
}