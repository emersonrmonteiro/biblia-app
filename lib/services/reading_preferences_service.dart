import 'package:shared_preferences/shared_preferences.dart';

/// Persists user preferences that affect the Bible reading experience.
class ReadingPreferencesService {
  static const _keyShowDualLanguage = 'showDualLanguage';

  /// Whether to show primary and secondary verses interleaved.
  static Future<bool> getShowDualLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowDualLanguage) ?? false;
  }

  static Future<void> setShowDualLanguage(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowDualLanguage, value);
  }
}
