import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book_id_mapping.dart';
import 'verse_cache_service.dart';

class SecondaryVerse {
  final int verse;
  final String text;

  SecondaryVerse({required this.verse, required this.text});

  factory SecondaryVerse.fromJson(Map<String, dynamic> json) {
    // Remove HTML tags that some versions include (e.g. <S>...</S> in KJV)
    String rawText = json['text'] as String? ?? '';
    rawText = rawText.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return SecondaryVerse(verse: json['verse'] as int? ?? 0, text: rawText);
  }

  Map<String, dynamic> toJson() => {'verse': verse, 'text': text};
}

class SecondaryBibleService {
  static const _baseUrl = 'https://bolls.life/get-text';

  // In-memory cache: key = "translationId/bookId/chapter"
  static final Map<String, List<SecondaryVerse>> _cache = {};

  /// Fetches a chapter.
  /// Checks: in-memory cache → disk cache → API (then saves to both caches).
  /// [translationId] - e.g. "WEB", "KJV", "ARA"
  /// [normalizedTitle] - local book name, e.g. "genesis"
  /// [chapter] - chapter number (1-based)
  static Future<List<SecondaryVerse>> getChapter({
    required String translationId,
    required String normalizedTitle,
    required int chapter,
  }) async {
    final bookId = getBookId(normalizedTitle);
    if (bookId == null) {
      return [];
    }

    final cacheKey = '$translationId/$bookId/$chapter';

    // 1. Return from in-memory cache if available
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // 2. Check persistent (disk) cache
    final cachedVerses = await VerseCacheService.getCachedChapter(
      translationId: translationId,
      bookId: bookId,
      chapter: chapter,
    );
    if (cachedVerses != null && cachedVerses.isNotEmpty) {
      _cache[cacheKey] = cachedVerses;
      return cachedVerses;
    }

    // 3. Fetch from API
    try {
      final url = Uri.parse('$_baseUrl/$translationId/$bookId/$chapter/');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final verses = data
            .map((e) => SecondaryVerse.fromJson(e as Map<String, dynamic>))
            .toList();

        // Save to in-memory cache
        _cache[cacheKey] = verses;

        // Save to persistent cache (fire and forget)
        VerseCacheService.cacheChapter(
          translationId: translationId,
          bookId: bookId,
          chapter: chapter,
          verses: verses,
        );

        return verses;
      }

      return [];
    } catch (_) {
      // Network error, timeout, etc.
      return [];
    }
  }

  /// Gets a single verse from a chapter.
  /// [verseNumber] is the verse number as a string (e.g. "1", "2").
  static Future<SecondaryVerse?> getVerse({
    required String translationId,
    required String normalizedTitle,
    required int chapter,
    required String verseNumber,
  }) async {
    final verses = await getChapter(
      translationId: translationId,
      normalizedTitle: normalizedTitle,
      chapter: chapter,
    );

    if (verses.isEmpty) return null;

    final verseNum = int.tryParse(verseNumber);
    if (verseNum == null) return null;

    try {
      return verses.firstWhere((v) => v.verse == verseNum);
    } catch (_) {
      return null;
    }
  }

  /// Returns verses from in-memory or disk cache only — never calls the network.
  /// Returns an empty list if the chapter is not cached.
  static Future<List<SecondaryVerse>> getChapterFromCacheOnly({
    required String translationId,
    required String normalizedTitle,
    required int chapter,
  }) async {
    final bookId = getBookId(normalizedTitle);
    if (bookId == null) return [];

    final cacheKey = '$translationId/$bookId/$chapter';

    // 1. In-memory cache
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // 2. Disk cache only (no network)
    final cachedVerses = await VerseCacheService.getCachedChapter(
      translationId: translationId,
      bookId: bookId,
      chapter: chapter,
    );
    if (cachedVerses != null && cachedVerses.isNotEmpty) {
      _cache[cacheKey] = cachedVerses;
      return cachedVerses;
    }

    return [];
  }

  /// Clears the in-memory cache.
  static void clearCache() {
    _cache.clear();
  }

  /// Adds verses to the in-memory cache directly.
  static void addToCache(
    String translationId,
    int bookId,
    int chapter,
    List<SecondaryVerse> verses,
  ) {
    final cacheKey = '$translationId/$bookId/$chapter';
    _cache[cacheKey] = verses;
  }
}
