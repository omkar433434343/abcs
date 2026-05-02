import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OfflineCache {
  static const _storage = FlutterSecureStorage();

  static String _key(String key) => 'cache_$key';

  static Future<void> write(String key, dynamic value) async {
    await _storage.write(key: _key(key), value: jsonEncode(value));
  }

  static Future<dynamic> read(String key) async {
    final raw = await _storage.read(key: _key(key));
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  static Future<void> remove(String key) async {
    await _storage.delete(key: _key(key));
  }
}
