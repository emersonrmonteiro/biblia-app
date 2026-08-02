import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_config.dart';

class LanguageService {
  static const _primaryTranslationKey = 'primaryTranslation';
  static const _secondaryTranslationKey = 'secondaryTranslation';

  static BibleTranslation get defaultPrimary =>
      availableLanguages[0].translations[0]; // A Mensagem

  static BibleTranslation get defaultSecondary =>
      availableLanguages[1].translations[0]; // WEB

  static Future<LanguageConfig> getLanguageConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final primaryId = prefs.getString(_primaryTranslationKey);
    final secondaryId = prefs.getString(_secondaryTranslationKey);

    final primary = _findTranslation(primaryId) ?? defaultPrimary;
    final secondary = _findTranslation(secondaryId) ?? defaultSecondary;

    return LanguageConfig(
      primaryTranslation: primary,
      secondaryTranslation: secondary,
    );
  }

  static Future<void> setPrimaryTranslation(String translationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_primaryTranslationKey, translationId);
  }

  static Future<void> setSecondaryTranslation(String translationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_secondaryTranslationKey, translationId);
  }

  static Future<void> saveLanguageConfig(LanguageConfig config) async {
    await setPrimaryTranslation(config.primaryTranslation.id);
    await setSecondaryTranslation(config.secondaryTranslation.id);
  }

  /// Finds a translation by ID across all available languages.
  static BibleTranslation? _findTranslation(String? id) {
    if (id == null) return null;
    for (final language in availableLanguages) {
      for (final translation in language.translations) {
        if (translation.id == id) return translation;
      }
    }
    return null;
  }

  /// Returns the language code (pt, en) for a given translation.
  static String getLanguageCode(BibleTranslation translation) {
    for (final language in availableLanguages) {
      if (language.translations.any((t) => t.id == translation.id)) {
        return language.code;
      }
    }
    return 'en';
  }
}
