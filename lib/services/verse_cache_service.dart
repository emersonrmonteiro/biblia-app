import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'secondary_bible_service.dart';

/// Persistent cache for secondary Bible verses.
/// Stores fetched chapters as JSON files in the app's documents directory.
/// Structure: `app_docs/bible_cache/translationId/bookId/chapter.json`
class VerseCacheService {
  static String? _cacheDir;

  /// Initializes the cache directory path.
  static Future<void> init() async {
    if (_cacheDir != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _cacheDir = '${dir.path}/bible_cache';
  }

  /// Returns cached verses for a chapter, or null if not cached.
  static Future<List<SecondaryVerse>?> getCachedChapter({
    required String translationId,
    required int bookId,
    required int chapter,
  }) async {
    await init();

    final file = _getFile(translationId, bookId, chapter);
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      final data = json.decode(content) as List;
      return data
          .map((e) => SecondaryVerse.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt file — delete it
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }
  }

  /// Saves a chapter's verses to the persistent cache.
  static Future<void> cacheChapter({
    required String translationId,
    required int bookId,
    required int chapter,
    required List<SecondaryVerse> verses,
  }) async {
    await init();

    final file = _getFile(translationId, bookId, chapter);

    try {
      // Create directories if needed
      await file.parent.create(recursive: true);

      final jsonData = verses.map((v) => v.toJson()).toList();
      await file.writeAsString(json.encode(jsonData));
    } catch (_) {
      // Silently fail — cache is optional
    }
  }

  /// Checks if a chapter is cached.
  static Future<bool> isCached({
    required String translationId,
    required int bookId,
    required int chapter,
  }) async {
    await init();
    return _getFile(translationId, bookId, chapter).existsSync();
  }

  /// Clears all cached data.
  static Future<void> clearAll() async {
    await init();
    final dir = Directory(_cacheDir!);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// Deletes all cached chapters for a specific translation.
  static Future<void> deleteTranslation(String translationId) async {
    await init();
    final dir = Directory('$_cacheDir/$translationId');
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// Returns how many chapters are cached for a given translation.
  static Future<int> countCachedChapters(String translationId) async {
    await init();
    final dir = Directory('$_cacheDir/$translationId');
    if (!dir.existsSync()) return 0;

    int count = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.json')) {
        count++;
      }
    }
    return count;
  }

  /// Returns true if all expected chapters are cached for a translation.
  /// [totalChapters] is the full chapter count for the translation (e.g. 1189
  /// for a complete Bible).
  static Future<bool> isTranslationFullyDownloaded(
    String translationId,
    int totalChapters,
  ) async {
    final cached = await countCachedChapters(translationId);
    return cached >= totalChapters;
  }

  /// Returns the cache size in bytes.
  static Future<int> getCacheSize() async {
    await init();
    final dir = Directory(_cacheDir!);
    if (!dir.existsSync()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Returns the cache size in bytes for a specific translation.
  static Future<int> getTranslationCacheSize(String translationId) async {
    await init();
    final dir = Directory('$_cacheDir/$translationId');
    if (!dir.existsSync()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  static File _getFile(String translationId, int bookId, int chapter) {
    return File('$_cacheDir/$translationId/$bookId/$chapter.json');
  }
}
