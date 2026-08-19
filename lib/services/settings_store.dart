import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const _keyHapticsEnabled = 'settings_haptics_enabled';

  static Future<bool> loadHapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHapticsEnabled) ?? true;
  }

  static Future<void> saveHapticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHapticsEnabled, enabled);
  }
}
