import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/models.dart';

// ── Offline queue item ────────────────────────────────────────────────────────
class QueueItem {
  final String id;        // unique local id
  final String type;      // 'patient' | 'triage'
  final Map<String, dynamic> data;
  final DateTime createdAt;

  QueueItem({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'created_at': createdAt.toIso8601String(),
  };

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
    id: json['id'],
    type: json['type'],
    data: Map<String, dynamic>.from(json['data']),
    createdAt: DateTime.parse(json['created_at']),
  );
}

// ── Offline Queue Service ────────────────────────────────────────────────────
class OfflineQueue {
  static const _storage = FlutterSecureStorage();
  static const _key = 'offline_queue';

  static Future<List<QueueItem>> _load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => QueueItem.fromJson(e)).toList();
  }

  static Future<void> _save(List<QueueItem> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  static Future<void> enqueue(QueueItem item) async {
    final items = await _load();
    items.add(item);
    await _save(items);
  }

  static Future<List<QueueItem>> getAll() => _load();

  static Future<void> remove(String id) async {
    final items = await _load();
    items.removeWhere((e) => e.id == id);
    await _save(items);
  }

  static Future<int> count() async {
    final items = await _load();
    return items.length;
  }
}

// ── Connectivity Provider ────────────────────────────────────────────────────
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

// ── Offline Queue Count Provider ─────────────────────────────────────────────
final offlineQueueCountProvider = FutureProvider<int>((ref) => OfflineQueue.count());

// ── Sync Service ─────────────────────────────────────────────────────────────
class SyncService {
  static bool _syncing = false;

  static Future<void> syncAll() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final items = await OfflineQueue.getAll();
      for (final item in items) {
        try {
          if (item.type == 'patient') {
            await ApiClient().dio.post(ApiEndpoints.patients, data: item.data);
          } else if (item.type == 'triage') {
            await ApiClient().dio.post(ApiEndpoints.triageRecords, data: item.data);
          }
          await OfflineQueue.remove(item.id);
        } catch (_) {
          // Leave in queue if still fails
        }
      }
    } finally {
      _syncing = false;
    }
  }
}
