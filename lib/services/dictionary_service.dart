import 'dart:convert';

import 'package:flutter/services.dart';

class DictionaryService {
  static Map<String, String>? _dictionary;
  static bool _isLoading = false;

  /// Loads the offline PT-EN dictionary from assets.
  static Future<void> load() async {
    if (_dictionary != null || _isLoading) return;

    _isLoading = true;
    try {
      final data = await rootBundle.loadString('assets/dictionary/pt_en.json');
      final Map<String, dynamic> jsonMap = json.decode(data);
      _dictionary = jsonMap.map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      _dictionary = {};
    } finally {
      _isLoading = false;
    }
  }

  /// Looks up a word in the offline dictionary.
  /// Returns the translation or null if not found.
  /// Normalizes the input (lowercase, removes accents) for better matching.
  static Future<String?> translate(String word) async {
    await load();
    if (_dictionary == null) return null;

    final normalized = _normalize(word.trim());
    if (normalized.isEmpty) return null;

    // Try exact match first (with original lowercase)
    final lowerWord = word.trim().toLowerCase();
    if (_dictionary!.containsKey(lowerWord)) {
      return _dictionary![lowerWord];
    }

    // Try normalized match (without accents)
    for (final entry in _dictionary!.entries) {
      if (_normalize(entry.key) == normalized) {
        return entry.value;
      }
    }

    return null;
  }

  /// Checks if the dictionary is loaded.
  static bool get isLoaded => _dictionary != null;

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
