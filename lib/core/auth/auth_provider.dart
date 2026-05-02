import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/models.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_cache.dart';

// ── Auth state ───────────────────────────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isLoggedIn;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isLoggedIn = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isLoggedIn,
  }) => AuthState(
    user: user ?? this.user,
    isLoading: isLoading ?? this.isLoading,
    error: error,
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final hasToken = await ApiClient.hasToken();
    if (!hasToken) return;

    final cachedUser = await OfflineCache.read('auth_user');
    if (cachedUser is Map) {
      state = AuthState(user: UserModel.fromJson(Map<String, dynamic>.from(cachedUser)), isLoggedIn: true);
    }

    try {
      final me = await ApiClient().getCachedMap(ApiEndpoints.me, cacheKey: 'auth_user');
      final user = UserModel.fromJson(me);
      state = AuthState(user: user, isLoggedIn: true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await ApiClient.clearToken();
        await OfflineCache.remove('auth_user');
        state = const AuthState();
      }
    }
  }

  Future<bool> login(String employeeId, String password, String role) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiClient().dio.post(
        ApiEndpoints.login,
        data: {'employee_id': employeeId, 'password': password, 'role': role},
      );
      final token = response.data['access_token'];
      final userData = response.data['user'];
      await ApiClient.saveToken(token);
      await ApiClient.saveRole(userData['role']);
      await ApiClient.saveUserId(userData['id']);
      await OfflineCache.write('auth_user', userData);
      final user = UserModel.fromJson(userData);
      state = AuthState(user: user, isLoggedIn: true);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Login failed. Please try again.';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient.clearToken();
    await OfflineCache.remove('auth_user');
    state = const AuthState();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await ApiClient().dio.patch(ApiEndpoints.updateProfile, data: data);
      // Refresh profile
      final me = await ApiClient().getCachedMap(ApiEndpoints.me, cacheKey: 'auth_user');
      final user = UserModel.fromJson(me);
      state = state.copyWith(user: user);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        await OfflineQueue.enqueueRequest(
          method: 'PATCH',
          endpoint: ApiEndpoints.updateProfile,
          data: data,
        );
      }
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
