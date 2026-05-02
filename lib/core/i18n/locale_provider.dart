import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier()..load(),
);

class LocaleNotifier extends StateNotifier<Locale> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_locale';

  LocaleNotifier() : super(const Locale('en'));

  Future<void> load() async {
    final code = await _storage.read(key: _key);
    if (code != null && ['en', 'hi', 'kn'].contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(String code) async {
    if (!['en', 'hi', 'kn'].contains(code)) return;
    state = Locale(code);
    await _storage.write(key: _key, value: code);
  }
}
