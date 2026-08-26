import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../models/device_reading.dart';
import '../models/owned_device.dart';
import '../config/firebase_options.dart';

class DatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: DefaultFirebaseOptions.databaseURL,
  );

  static const String _baseUrl = DefaultFirebaseOptions.databaseURL;

  Future<List<OwnedDevice>> getOwnedDevices(String uid) async {
    try {
      final snap = await _db.ref('users/$uid/owned_devices').get();
      if (snap.exists && snap.value != null) {
        final data = snap.value;
        if (data is Map) {
          return data.entries.map((e) {
            return OwnedDevice.fromMap(e.key.toString(), e.value);
          }).toList();
        }
      }
    } catch (_) {
      // Fallback to REST API
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final uri = Uri.parse('$_baseUrl/users/$uid/owned_devices.json?auth=${token ?? ""}');
      final res = await http.get(uri);
      if (res.statusCode == 200 && res.body != 'null') {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return decoded.entries.map((e) {
            return OwnedDevice.fromMap(e.key.toString(), e.value);
          }).toList();
        }
      }
    }
    return [];
  }

  Stream<List<OwnedDevice>> streamOwnedDevices(String uid) {
    return _db.ref('users/$uid/owned_devices').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) return <OwnedDevice>[];
      return val.entries.map((e) {
        return OwnedDevice.fromMap(e.key.toString(), e.value);
      }).toList();
    }).handleError((_) => <OwnedDevice>[]);
  }

  Future<List<DeviceReading>> getDeviceReadings(String mac) async {
    try {
      final snap = await _db.ref('devices/$mac').get();
      if (snap.exists && snap.value != null) {
        final data = snap.value;
        if (data is Map) {
          final list = data.entries.map((e) {
            return DeviceReading.fromJson(e.key.toString(), e.value);
          }).toList();
          list.sort((a, b) => (a.ts ?? 0).compareTo(b.ts ?? 0));
          return list;
        }
      }
    } catch (_) {
      // Fallback to REST API
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final uri = Uri.parse('$_baseUrl/devices/$mac.json?auth=${token ?? ""}');
      final res = await http.get(uri);
      if (res.statusCode == 200 && res.body != 'null') {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final list = decoded.entries.map((e) {
            return DeviceReading.fromJson(e.key.toString(), e.value);
          }).toList();
          list.sort((a, b) => (a.ts ?? 0).compareTo(b.ts ?? 0));
          return list;
        }
      }
    }
    return [];
  }

  Stream<List<DeviceReading>> streamDeviceReadings(String mac) {
    return _db.ref('devices/$mac').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) return <DeviceReading>[];
      final list = val.entries.map((e) {
        return DeviceReading.fromJson(e.key.toString(), e.value);
      }).toList();
      list.sort((a, b) => (a.ts ?? 0).compareTo(b.ts ?? 0));
      return list;
    }).handleError((_) => <DeviceReading>[]);
  }
}
