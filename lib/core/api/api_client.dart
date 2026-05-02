import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/endpoints.dart';
import '../offline/offline_cache.dart';

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

  static bool _isOfflineError(Object error) {
    if (error is! DioException) return false;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionTimeout;
  }

  Future<List<dynamic>> getCachedList(String path, {String? cacheKey}) async {
    final key = cacheKey ?? path;
    try {
      final res = await _dio.get(path);
      final data = (res.data as List).cast<dynamic>();
      await OfflineCache.write(key, data);
      return data;
    } catch (e) {
      if (_isOfflineError(e)) {
        final cached = await OfflineCache.read(key);
        if (cached is List) return cached.cast<dynamic>();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCachedMap(String path, {String? cacheKey}) async {
    final key = cacheKey ?? path;
    try {
      final res = await _dio.get(path);
      final data = Map<String, dynamic>.from(res.data as Map);
      await OfflineCache.write(key, data);
      return data;
    } catch (e) {
      if (_isOfflineError(e)) {
        final cached = await OfflineCache.read(key);
        if (cached is Map) return Map<String, dynamic>.from(cached);
      }
      rethrow;
    }
  }

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
