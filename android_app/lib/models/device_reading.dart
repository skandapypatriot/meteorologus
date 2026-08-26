class DeviceReading {
  final String? key;
  final double? t;
  final double? h;
  final double? p;
  final int? ts;
  final dynamic weatherCode;
  final List<dynamic>? forecast;

  const DeviceReading({
    this.key,
    this.t,
    this.h,
    this.p,
    this.ts,
    this.weatherCode,
    this.forecast,
  });

  factory DeviceReading.fromJson(String? key, dynamic json) {
    if (json == null || json is! Map) {
      return DeviceReading(key: key);
    }

    final map = Map<String, dynamic>.from(
      json.map((k, v) => MapEntry(k.toString(), v)),
    );

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    List<dynamic>? parseForecast(dynamic val) {
      if (val == null) return null;
      if (val is List) return List<dynamic>.from(val);
      if (val is Map) return val.values.toList();
      return null;
    }

    return DeviceReading(
      key: key,
      t: parseDouble(map['t']),
      h: parseDouble(map['h']),
      p: parseDouble(map['p']),
      ts: parseInt(map['ts']),
      weatherCode: map['weather_code'] ?? map['weatherCode'],
      forecast: parseForecast(map['forecast']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (t != null) 't': t,
      if (h != null) 'h': h,
      if (p != null) 'p': p,
      if (ts != null) 'ts': ts,
      if (weatherCode != null) 'weather_code': weatherCode,
      if (forecast != null) 'forecast': forecast,
    };
  }
}
