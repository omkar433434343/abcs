import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/endpoints.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const _storage = FlutterSecureStorage();
  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token expired — clear storage; router will redirect to login
          await _storage.deleteAll();
        }
        handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  // ── Auth helpers ─────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) =>
      _storage.write(key: 'jwt_token', value: token);

  static Future<String?> getToken() => _storage.read(key: 'jwt_token');

  static Future<void> clearToken() => _storage.deleteAll();

  static Future<bool> hasToken() async {
    final token = await _storage.read(key: 'jwt_token');
    return token != null;
  }

  static Future<void> saveRole(String role) =>
      _storage.write(key: 'user_role', value: role);

  static Future<String?> getRole() => _storage.read(key: 'user_role');

  static Future<void> saveUserId(String id) =>
      _storage.write(key: 'user_id', value: id);

  static Future<String?> getUserId() => _storage.read(key: 'user_id');
}
