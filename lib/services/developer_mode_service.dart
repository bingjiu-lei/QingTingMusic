import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'app_preferences_service.dart';

class DeveloperModeService {
  DeveloperModeService({AppPreferencesService? preferences})
    : _preferences = preferences ?? AppPreferencesService();

  static const _enabledKey = 'developer.enabled';
  static const _salt = 'QingTingMusicDeveloperMode';
  static const _passphraseHash =
      '05659dd17015adc32ab97339dc364138ebd60b3438405b874408166ed3f5f9f0';

  final AppPreferencesService _preferences;

  Future<bool> loadEnabled() async {
    return await _preferences.read(_enabledKey) == true;
  }

  Future<void> saveEnabled(bool value) async {
    await _preferences.write(_enabledKey, value);
  }

  bool verifyPassphrase(String value) {
    return verify(value);
  }

  static bool verify(String value) {
    final input = value.trim();
    final digest = sha256.convert(utf8.encode('$input:$_salt')).toString();
    return digest == _passphraseHash;
  }
}
