import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/language_config.dart';
import '../models/livro.dart';
import '../models/search_result.dart';
import 'secondary_bible_service.dart';

class BibleSearchService {
  /// Searches all books/chapters for [query] using [translation] as the source.
  ///
  /// - Local translations (isLocal == true): reads from bundled asset JSON files.
  /// - API translations (isLocal == false): reads from in-memory / disk cache
  ///   via [SecondaryBibleService]. Chapters not yet cached are skipped to keep
  ///   search fast and offline-friendly.
  static Future<List<SearchResult>> search(
    String query,
    BibleTranslation translation,
    List<Livro> livros,
  ) async {
    if (query.trim().length < 3) return [];

    final normalizedQuery = _normalize(query);
    final results = <SearchResult>[];

    for (final livro in livros) {
      for (int cap = 1; cap <= livro.chaptersCount; cap++) {
        final verses = translation.isLocal
            ? await _loadLocalChapter(translation.id, livro, cap)
            : await _loadCachedChapter(translation.id, livro, cap);

        for (final verse in verses) {
          final content = verse['content'] as String? ?? '';
          final title = verse['title'] as String? ?? '';

          if (_normalize(content).contains(normalizedQuery) ||
              _normalize(title).contains(normalizedQuery)) {
            results.add(
              SearchResult(
                livro: livro,
                capitulo: cap,
                verseNumber: verse['number'] ?? '',
                verseContent: content,
                verseTitle: title,
              ),
            );
          }
        }
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Local asset loader
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> _loadLocalChapter(
    String translationId,
    Livro livro,
    int chapter,
  ) async {
    final path =
        'assets/versoes/$translationId/${livro.testament}-testamento/${livro.normalizedTitle}/$chapter.json';
    try {
      final content = await rootBundle.loadString(path);
      final data = json.decode(content) as List;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Cache-only loader for API translations (no network call during search)
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> _loadCachedChapter(
    String translationId,
    Livro livro,
    int chapter,
  ) async {
    // Use the in-memory / disk cache only — do not hit the network during search.
    final verses = await SecondaryBibleService.getChapterFromCacheOnly(
      translationId: translationId,
      normalizedTitle: livro.normalizedTitle,
      chapter: chapter,
    );

    return verses
        .map(
          (sv) => <String, dynamic>{
            'number': sv.verse.toString(),
            'content': sv.text,
            'title': '',
          },
        )
        .toList();
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');
  }
}
