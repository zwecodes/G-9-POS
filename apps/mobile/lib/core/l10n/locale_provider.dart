import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const kAppLocaleKey = 'g9pos_locale';

/// Supported shop UI languages. Default is Myanmar for the Pin Laung owner.
const kSupportedLocales = <Locale>[
  Locale('my'),
  Locale('en'),
];

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._storage) : super(const Locale('my')) {
    _restore();
  }

  final FlutterSecureStorage _storage;

  Future<void> _restore() async {
    final code = await _storage.read(key: kAppLocaleKey);
    if (code == 'en' || code == 'my') {
      state = Locale(code!);
    }
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    if (code != 'en' && code != 'my') return;
    await _storage.write(key: kAppLocaleKey, value: code);
    state = Locale(code);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(const FlutterSecureStorage());
});
