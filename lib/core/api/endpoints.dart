class ApiEndpoints {
  static const String baseUrl = 'https://swasthya-setu-full.onrender.com';

  // Auth
  static const String login = '/api/v1/auth/login';
  static const String register = '/api/v1/auth/register';

  // Users
  static const String me = '/api/v1/users/me';
  static const String updateProfile = '/api/v1/users/profile';
  static const String ashaWorkers = '/api/v1/users/asha';

  // Patients
  static const String patients = '/api/v1/patients/';
  static String patientById(String id) => '/api/v1/patients/$id';

  // Triage
  static const String triageRecords = '/api/v1/triage_records/';
  static const String voiceTriage = '/api/v1/triage_records/voice-triage';
  static const String aiSuggestion = '/api/v1/triage_records/ai-suggestion';
  static String markReviewed(String id) => '/api/v1/triage_records/$id/reviewed';

  // Outbreaks
  static const String outbreaks = '/api/v1/outbreaks';

  // Reviews
  static const String reviews = '/api/v1/reviews';

  // Patient progress timeline
  static const String patientProgress = '/api/v1/patient_progress/';
  static const List<String> patientProgressCandidates = [
    '/api/v1/patient_progress/',
    '/api/v1/patient-progress/',
    '/api/v1/progress_updates/',
  ];
}
