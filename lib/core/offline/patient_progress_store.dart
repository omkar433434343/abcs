import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class PatientProgressStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'patient_progress_local';

  static Future<List<PatientProgressUpdateModel>> getAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PatientProgressUpdateModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> add(PatientProgressUpdateModel item) async {
    final items = await getAll();
    items.add(item);
    await _storage.write(
      key: _key,
      value: jsonEncode(items.map((e) => {
            'id': e.id,
            'patient_id': e.patientId,
            'status': e.status,
            'symptoms': e.symptoms,
            'notes': e.notes,
            'created_at': e.createdAt,
          }).toList()),
    );
  }
}
