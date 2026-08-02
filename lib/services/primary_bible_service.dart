import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/language_config.dart';
import '../models/versiculo.dart';
import 'secondary_bible_service.dart';
import 'verse_cache_service.dart';

/// Loads chapters for the primary (reading) translation.
///
/// Strategy:
///   - [BibleTranslation.isLocal] == true  → reads from bundled asset JSON
///   - [BibleTranslation.isLocal] == false → in-memory cache → disk cache → API
///     (delegates to [SecondaryBibleService] which already implements this chain)
class PrimaryBibleService {
  /// Returns the list of [Versiculo] for the given chapter.
  ///
  /// [translation] – the primary translation selected by the user.
  /// [testament]   – 'velho' or 'novo'.
  /// [normalizedTitle] – e.g. 'genesis', 'mateus'.
  /// [chapter]     – chapter number (1-based).
  static Future<List<Versiculo>> getChapter({
    required BibleTranslation translation,
    required String testament,
    required String normalizedTitle,
    required int chapter,
  }) async {
    if (translation.isLocal) {
      return _loadFromAsset(
        translationId: translation.id,
        testament: testament,
        normalizedTitle: normalizedTitle,
        chapter: chapter,
      );
    } else {
      return _loadFromApi(
        translation: translation,
        normalizedTitle: normalizedTitle,
        chapter: chapter,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Local asset path  (only "a-mensagem" currently)
  // ---------------------------------------------------------------------------

  static Future<List<Versiculo>> _loadFromAsset({
    required String translationId,
    required String testament,
    required String normalizedTitle,
    required int chapter,
  }) async {
    final path =
        'assets/versoes/$translationId/$testament-testamento/$normalizedTitle/$chapter.json';
    try {
      final content = await rootBundle.loadString(path);
      final data = json.decode(content) as List;
      return data.map((e) => Versiculo.fromJson(e)).toList();
    } catch (e) {
      debugPrint('PrimaryBibleService: erro ao carregar asset $path – $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // API / disk cache (reuses SecondaryBibleService's cache chain)
  // ---------------------------------------------------------------------------

  static Future<List<Versiculo>> _loadFromApi({
    required BibleTranslation translation,
    required String normalizedTitle,
    required int chapter,
  }) async {
    final secondaryVerses = await SecondaryBibleService.getChapter(
      translationId: translation.id,
      normalizedTitle: normalizedTitle,
      chapter: chapter,
    );

    // Convert SecondaryVerse → Versiculo so the rest of the app stays uniform.
    return secondaryVerses
        .map(
          (sv) => Versiculo(
            number: sv.verse.toString(),
            content: sv.text,
            title: '',
          ),
        )
        .toList();
  }

  /// Pre-warms the in-memory cache for a chapter without waiting for the result.
  /// Useful to call for the next/previous chapter while the user is reading.
  static void prefetch({
    required BibleTranslation translation,
    required String normalizedTitle,
    required int chapter,
  }) {
    if (translation.isLocal) return; // assets are instant, no need to prefetch
    SecondaryBibleService.getChapter(
      translationId: translation.id,
      normalizedTitle: normalizedTitle,
      chapter: chapter,
    );
  }

  /// Counts how many chapters are cached on disk for a non-local translation.
  /// Returns 0 for local translations (always fully available).
  static Future<int> countCachedChapters(BibleTranslation translation) async {
    if (translation.isLocal) return 0;
    return VerseCacheService.countCachedChapters(translation.id);
  }
}
