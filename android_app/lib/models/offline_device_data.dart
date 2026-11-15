class OfflineInferenceRecord {
  final int ts;
  final double temp;
  final double humidity;
  final double pressure;
  final int currentWeatherCode;
  final List<int> forecastCodes;

  OfflineInferenceRecord({
    required this.ts,
    required this.temp,
    required this.humidity,
    required this.pressure,
    required this.currentWeatherCode,
    required this.forecastCodes,
  });

  factory OfflineInferenceRecord.fromJson(Map<String, dynamic> json) {
    return OfflineInferenceRecord(
      ts: json['ts'] ?? 0,
      temp: (json['temp'] ?? 0.0).toDouble(),
      humidity: (json['humidity'] ?? 0.0).toDouble(),
      pressure: (json['pressure'] ?? 0.0).toDouble(),
      currentWeatherCode: json['currentWeatherCode'] ?? -1,
      forecastCodes: (json['forecastCodes'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [-1, -1, -1],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ts': ts,
      'temp': temp,
      'humidity': humidity,
      'pressure': pressure,
      'currentWeatherCode': currentWeatherCode,
      'forecastCodes': forecastCodes,
    };
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(ts * 1000);
}

class OfflineDeviceData {
  final String deviceId;
  final bool offlineMode;
  final bool hotspotActive;
  final int connectedClients;
  final int inferenceCount;
  final int uptime;
  final int freeHeap;
  final OfflineInferenceRecord? latest;
  final List<int> forecast;
  final List<OfflineInferenceRecord> history;

  OfflineDeviceData({
    required this.deviceId,
    required this.offlineMode,
    required this.hotspotActive,
    required this.connectedClients,
    required this.inferenceCount,
    required this.uptime,
    required this.freeHeap,
    this.latest,
    required this.forecast,
    required this.history,
  });

  factory OfflineDeviceData.fromJson(Map<String, dynamic> json) {
    return OfflineDeviceData(
      deviceId: json['deviceId'] ?? '',
      offlineMode: json['offlineMode'] ?? false,
      hotspotActive: json['hotspotActive'] ?? false,
      connectedClients: json['connectedClients'] ?? 0,
      inferenceCount: json['inferenceCount'] ?? 0,
      uptime: json['uptime'] ?? 0,
      freeHeap: json['freeHeap'] ?? 0,
      latest: json['latest'] != null
          ? OfflineInferenceRecord.fromJson(json['latest'])
          : null,
      forecast: (json['forecast'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [-1, -1, -1, -1],
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => OfflineInferenceRecord.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class HotspotInfo {
  final String ssid;
  final String password;
  final String ipAddress;

  HotspotInfo({
    required this.ssid,
    required this.password,
    required this.ipAddress,
  });

  String get apiUrl => 'http://$ipAddress/api/data';
}