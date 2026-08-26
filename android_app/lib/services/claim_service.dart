import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/firebase_options.dart';

class ClaimService {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: DefaultFirebaseOptions.databaseURL,
  );

  static const String _baseUrl = DefaultFirebaseOptions.databaseURL;
  static final RegExp _delimiterRegex = RegExp(r'[:-]');
  static final RegExp macRegex = RegExp(r'^[A-Fa-f0-9]{12}$');

  static String normalizeMac(String input) {
    return input.replaceAll(_delimiterRegex, '').replaceAll(' ', '').toUpperCase();
  }

  static bool isValidMac(String input) {
    final cleaned = normalizeMac(input);
    return macRegex.hasMatch(cleaned);
  }

  Future<bool> isDeviceClaimed(String mac) async {
    final cleanMac = normalizeMac(mac);
    try {
      final snap = await _db.ref('claimed_devices/$cleanMac').get();
      return snap.exists && snap.value != null;
    } catch (_) {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final uri = Uri.parse('$_baseUrl/claimed_devices/$cleanMac.json?auth=${token ?? ""}');
      final res = await http.get(uri);
      return res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty;
    }
  }

  Future<void> claimDevice({
    required String uid,
    required String mac,
  }) async {
    final cleanMac = normalizeMac(mac);
    if (!isValidMac(cleanMac)) {
      throw Exception('Invalid MAC address. Must be 12 hexadecimal characters.');
    }

    final token = const Uuid().v4().replaceAll('-', '').toUpperCase();
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _db.ref('claimed_devices/$cleanMac').set(token);
      await _db.ref('users/$uid/owned_devices/$cleanMac').set({
        'token': token,
        'claimed_at': now,
      });
    } catch (e) {
      // Fallback via REST
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final tokenQuery = idToken != null ? '?auth=$idToken' : '';

      final claimUri = Uri.parse('$_baseUrl/claimed_devices/$cleanMac.json$tokenQuery');
      final claimRes = await http.put(
        claimUri,
        body: jsonEncode(token),
        headers: {'Content-Type': 'application/json'},
      );

      if (claimRes.statusCode != 200) {
        throw Exception('Failed to claim device in claimed_devices: ${claimRes.body}');
      }

      final userUri = Uri.parse('$_baseUrl/users/$uid/owned_devices/$cleanMac.json$tokenQuery');
      final userRes = await http.put(
        userUri,
        body: jsonEncode({
          'token': token,
          'claimed_at': now,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (userRes.statusCode != 200) {
        throw Exception('Failed to record device in user profile: ${userRes.body}');
      }
    }
  }
}
