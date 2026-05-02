// ── User model ─────────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String employeeId;
  final String role;
  final String? fullName;
  final String? location;
  final String? district;
  final String? avatarB64;
  final String? bannerB64;

  const UserModel({
    required this.id,
    required this.employeeId,
    required this.role,
    this.fullName,
    this.location,
    this.district,
    this.avatarB64,
    this.bannerB64,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] ?? '',
    employeeId: json['employee_id'] ?? '',
    role: json['role'] ?? '',
    fullName: json['full_name'],
    location: json['location'],
    district: json['district'],
    avatarB64: json['avatar_b64'],
    bannerB64: json['banner_b64'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_id': employeeId,
    'role': role,
    'full_name': fullName,
    'location': location,
    'district': district,
  };
}

// ── Patient model ────────────────────────────────────────────────────────────
class PatientModel {
  final String id;
  final String name;
  final int? age;
  final String? gender;
  final String? village;
  final String? tehsil;
  final String? district;
  final bool pregnant;
  final String? abhaId;
  final String? createdAt;
  final bool pendingSync; // offline queue flag

  const PatientModel({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.village,
    this.tehsil,
    this.district,
    this.pregnant = false,
    this.abhaId,
    this.createdAt,
    this.pendingSync = false,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) => PatientModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    age: json['age'],
    gender: json['gender'],
    village: json['village'],
    tehsil: json['tehsil'],
    district: json['district'],
    pregnant: json['pregnant'] ?? false,
    abhaId: json['abha_id'],
    createdAt: json['created_at'],
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'gender': gender,
    'village': village,
    'tehsil': tehsil,
    'district': district,
    'pregnant': pregnant,
    'abha_id': abhaId,
  };
}

// ── Triage Record model ──────────────────────────────────────────────────────
class TriageRecordModel {
  final String id;
  final String? patientId;
  final String patientName;
  final List<String> symptoms;
  final String severity;
  final bool sickleCell;
  final String brief;
  final String? tehsil;
  final String? district;
  final double? latitude;
  final double? longitude;
  final bool reviewed;
  final String? transcript;
  final String? source;
  final String? createdAt;
  final bool pendingSync;

  const TriageRecordModel({
    required this.id,
    this.patientId,
    required this.patientName,
    required this.symptoms,
    required this.severity,
    required this.sickleCell,
    required this.brief,
    this.tehsil,
    this.district,
    this.latitude,
    this.longitude,
    this.reviewed = false,
    this.transcript,
    this.source,
    this.createdAt,
    this.pendingSync = false,
  });

  factory TriageRecordModel.fromJson(Map<String, dynamic> json) {
    final rawSymptoms = json['symptoms'];
    List<String> symptoms = [];
    if (rawSymptoms is List) {
      symptoms = rawSymptoms.map((e) => e.toString()).toList();
    }
    return TriageRecordModel(
      id: json['id'] ?? '',
      patientId: json['patient_id'],
      patientName: json['patient_name'] ?? '',
      symptoms: symptoms,
      severity: json['severity'] ?? 'yellow',
      sickleCell: json['sickle_cell_risk'] ?? false,
      brief: json['brief'] ?? '',
      tehsil: json['tehsil'],
      district: json['district'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      reviewed: json['reviewed'] ?? false,
      transcript: json['transcript'],
      source: json['source'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
    'patient_id': patientId,
    'patient_name': patientName,
    'symptoms': symptoms,
    'severity': severity,
    'sickle_cell_risk': sickleCell,
    'brief': brief,
    'tehsil': tehsil,
    'district': district,
    'latitude': latitude,
    'longitude': longitude,
  };
}

// ── Voice Triage Result (transient — not persisted until user confirms) ──────
class VoiceTriageResult {
  final String patientName;
  final String transcript;
  final List<String> symptoms;
  final String severity;
  final bool sickleCell;
  final String brief;

  const VoiceTriageResult({
    required this.patientName,
    required this.transcript,
    required this.symptoms,
    required this.severity,
    required this.sickleCell,
    required this.brief,
  });

  factory VoiceTriageResult.fromJson(Map<String, dynamic> json) {
    final rawSymptoms = json['symptoms'];
    return VoiceTriageResult(
      patientName: json['patient_name'] ?? '',
      transcript: json['transcript'] ?? '',
      symptoms: rawSymptoms is List
          ? rawSymptoms.map((e) => e.toString()).toList()
          : [],
      severity: json['severity'] ?? 'yellow',
      sickleCell: json['sickle_cell_risk'] ?? false,
      brief: json['brief'] ?? '',
    );
  }
}

// ── Outbreak model ───────────────────────────────────────────────────────────
class OutbreakModel {
  final int id;
  final int? year;
  final int? week;
  final String? state;
  final String? district;
  final String? disease;
  final int? cases;
  final int? deaths;
  final String? status;
  final double? latitude;
  final double? longitude;

  const OutbreakModel({
    required this.id,
    this.year,
    this.week,
    this.state,
    this.district,
    this.disease,
    this.cases,
    this.deaths,
    this.status,
    this.latitude,
    this.longitude,
  });

  factory OutbreakModel.fromJson(Map<String, dynamic> json) => OutbreakModel(
    id: json['id'] ?? 0,
    year: json['year'],
    week: json['week'],
    state: json['state'],
    district: json['district'],
    disease: json['disease'],
    cases: json['cases'],
    deaths: json['deaths'],
    status: json['status'],
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}

// ── Review model ──────────────────────────────────────────────────────────────
class ReviewModel {
  final String id;
  final String role;
  final int overall;
  final String? comment;
  final String? userName;
  final String? designation;
  final String? location;
  final String? createdAt;

  const ReviewModel({
    required this.id,
    required this.role,
    required this.overall,
    this.comment,
    this.userName,
    this.designation,
    this.location,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: json['id'] ?? '',
    role: json['role'] ?? '',
    overall: json['overall'] ?? 5,
    comment: json['comment'],
    userName: json['userName'],
    designation: json['designation'],
    location: json['location'],
    createdAt: json['created_at'],
  );
}

// ── Patient Progress Update model ─────────────────────────────────────────────
class PatientProgressUpdateModel {
  final String id;
  final String patientId;
  final String status;
  final List<String> symptoms;
  final String? notes;
  final String? createdAt;

  const PatientProgressUpdateModel({
    required this.id,
    required this.patientId,
    required this.status,
    required this.symptoms,
    this.notes,
    this.createdAt,
  });

  factory PatientProgressUpdateModel.fromJson(Map<String, dynamic> json) {
    final rawSymptoms = json['symptoms'];
    return PatientProgressUpdateModel(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patient_id'] ?? json['patientId'] ?? '').toString(),
      status: (json['status'] ?? 'stable').toString(),
      symptoms: rawSymptoms is List
          ? rawSymptoms.map((e) => e.toString()).toList()
          : rawSymptoms is String
              ? rawSymptoms
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .replaceAll('"', '')
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : <String>[],
      notes: json['notes']?.toString(),
      createdAt: (json['created_at'] ?? json['createdAt'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'patient_id': patientId,
    'status': status,
    'symptoms': symptoms,
    'notes': notes,
  };
}
