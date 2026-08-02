import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dictionary_service.dart';

class TranslationResult {
  final String original;
  final String translated;
  final TranslationSource source;

  TranslationResult({
    required this.original,
    required this.translated,
    required this.source,
  });
}

enum TranslationSource { api, dictionary, notFound }

class TranslationService {
  static const _baseUrl = 'https://api.mymemory.translated.net/get';

  // In-memory cache for translations: "word_sourceLang_targetLang" -> result
  static final Map<String, TranslationResult> _cache = {};

  /// Translates a word or short phrase.
  /// Tries MyMemory API first, falls back to offline dictionary.
  /// [text] - word or phrase to translate
  /// [sourceLang] - source language code (e.g. "pt")
  /// [targetLang] - target language code (e.g. "en")
  static Future<TranslationResult> translate({
    required String text,
    String sourceLang = 'pt',
    String targetLang = 'en',
  }) async {
    final cleanText = _cleanWord(text);
    if (cleanText.isEmpty) {
      return TranslationResult(
        original: text,
        translated: '',
        source: TranslationSource.notFound,
      );
    }

    final cacheKey = '${cleanText}_${sourceLang}_$targetLang';

    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Try API first
    final apiResult = await _translateViaApi(cleanText, sourceLang, targetLang);
    if (apiResult != null) {
      final result = TranslationResult(
        original: cleanText,
        translated: apiResult,
        source: TranslationSource.api,
      );
      _cache[cacheKey] = result;
      return result;
    }

    // Fallback to offline dictionary
    final dictResult = await DictionaryService.translate(cleanText);
    if (dictResult != null) {
      final result = TranslationResult(
        original: cleanText,
        translated: dictResult,
        source: TranslationSource.dictionary,
      );
      _cache[cacheKey] = result;
      return result;
    }

    // Not found anywhere
    final notFound = TranslationResult(
      original: cleanText,
      translated: '',
      source: TranslationSource.notFound,
    );
    return notFound;
  }

  /// Calls MyMemory API for translation.
  static Future<String?> _translateViaApi(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    try {
      final url = Uri.parse(_baseUrl).replace(
        queryParameters: {'q': text, 'langpair': '$sourceLang|$targetLang'},
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final responseData = data['responseData'] as Map<String, dynamic>?;

        if (responseData != null) {
          final translatedText = responseData['translatedText'] as String?;
          final match = responseData['match'] as num?;

          // Only accept translations with reasonable confidence
          // match >= 0.5 means at least 50% match quality
          if (translatedText != null &&
              translatedText.isNotEmpty &&
              (match == null || match >= 0.3)) {
            // Avoid returning the same text (API sometimes returns input as-is)
            if (translatedText.toLowerCase() != text.toLowerCase()) {
              return translatedText;
            }
          }
        }
      }
      return null;
    } catch (_) {
      // Network error, timeout, etc.
      return null;
    }
  }

  /// Removes punctuation and extra whitespace from a word.
  static String _cleanWord(String word) {
    return word
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .trim();
  }

  /// Clears the translation cache.
  static void clearCache() {
    _cache.clear();
  }
}
