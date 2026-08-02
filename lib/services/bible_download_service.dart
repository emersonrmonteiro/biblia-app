import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/book_id_mapping.dart';
import 'secondary_bible_service.dart';
import 'verse_cache_service.dart';

/// Represents a book entry from livros.json used during download.
class _BookEntry {
  final String normalizedTitle;
  final int chaptersCount;

  const _BookEntry({
    required this.normalizedTitle,
    required this.chaptersCount,
  });
}

/// Progress snapshot emitted while downloading a translation.
class DownloadProgress {
  /// Chapters completed so far.
  final int downloaded;

  /// Total chapters in the translation (1189 for a full Bible).
  final int total;

  /// Whether the download has been cancelled.
  final bool cancelled;

  /// Whether the download finished successfully.
  final bool completed;

  /// Error message, if any chapter failed fatally (network unreachable, etc.)
  final String? error;

  const DownloadProgress({
    required this.downloaded,
    required this.total,
    this.cancelled = false,
    this.completed = false,
    this.error,
  });

  double get fraction => total == 0 ? 0 : downloaded / total;

  bool get isActive => !cancelled && !completed && error == null;
}

/// Simple semaphore that limits the number of concurrent async tasks.
class _Semaphore {
  final int maxConcurrent;
  int _running = 0;
  final Queue<Completer<void>> _waitQueue = Queue();

  _Semaphore(this.maxConcurrent);

  Future<T> run<T>(Future<T> Function() task) async {
    await _acquire();
    try {
      return await task();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_running < maxConcurrent) {
      _running++;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
    _running++;
  }

  void _release() {
    _running--;
    if (_waitQueue.isNotEmpty) {
      final next = _waitQueue.removeFirst();
      next.complete();
    }
  }
}

/// Minimal queue implementation used by [_Semaphore].
class Queue<T> {
  final _list = <T>[];
  void add(T item) => _list.add(item);
  T removeFirst() => _list.removeAt(0);
  bool get isNotEmpty => _list.isNotEmpty;
}

/// Manages pre-fetching (bulk download) of entire Bible translations for
/// offline use. Uses the same Bolls.life API + VerseCacheService as the
/// regular reading flow so no duplicate storage is created.
class BibleDownloadService {
  /// Number of chapters fetched concurrently.
  static const int concurrency = 8;

  // Active download controllers, keyed by translationId.
  static final Map<String, StreamController<DownloadProgress>> _controllers =
      {};

  // Cancellation flags.
  static final Map<String, bool> _cancelled = {};

  /// Returns a stream of [DownloadProgress] for the given translation,
  /// starting the download if it isn't already running.
  ///
  /// The stream closes once the download completes, is cancelled, or fails.
  static Stream<DownloadProgress> downloadTranslation(String translationId) {
    // Reuse existing stream if already downloading.
    if (_controllers.containsKey(translationId)) {
      return _controllers[translationId]!.stream;
    }

    final controller = StreamController<DownloadProgress>.broadcast();
    _controllers[translationId] = controller;
    _cancelled[translationId] = false;

    // Start async download without awaiting.
    _runDownload(translationId, controller);

    return controller.stream;
  }

  /// Cancels an active download for [translationId].
  static void cancelDownload(String translationId) {
    _cancelled[translationId] = true;
  }

  /// Returns true if a download for [translationId] is currently active.
  static bool isDownloading(String translationId) {
    return _controllers.containsKey(translationId) &&
        !(_controllers[translationId]?.isClosed ?? true);
  }

  /// Clears all cached chapters for a translation (delete offline data).
  static Future<void> deleteTranslation(String translationId) async {
    await VerseCacheService.deleteTranslation(translationId);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static Future<void> _runDownload(
    String translationId,
    StreamController<DownloadProgress> controller,
  ) async {
    try {
      final books = await _loadBooks();
      final total = books.fold<int>(0, (sum, b) => sum + b.chaptersCount);

      // Emit initial progress immediately so UI can react.
      controller.add(DownloadProgress(downloaded: 0, total: total));

      // Flatten all (bookId, chapter) work items upfront.
      final workItems = <({int bookId, String normalizedTitle, int chapter})>[];
      for (final book in books) {
        final bookId = getBookId(book.normalizedTitle);
        if (bookId == null) continue;
        for (int ch = 1; ch <= book.chaptersCount; ch++) {
          workItems.add((
            bookId: bookId,
            normalizedTitle: book.normalizedTitle,
            chapter: ch,
          ));
        }
      }

      // Shared counter — safe because Dart is single-threaded (no isolates here).
      int downloaded = 0;

      // Semaphore caps concurrent HTTP requests at [concurrency].
      final semaphore = _Semaphore(concurrency);
      final futures = <Future<void>>[];

      for (final item in workItems) {
        // Bail out early if cancellation was requested before scheduling.
        if (_cancelled[translationId] == true) break;

        final future = semaphore.run(() async {
          // Re-check after the semaphore slot opens up.
          if (_cancelled[translationId] == true) return;

          final alreadyCached = await VerseCacheService.isCached(
            translationId: translationId,
            bookId: item.bookId,
            chapter: item.chapter,
          );

          if (!alreadyCached) {
            await _fetchAndCache(
              translationId: translationId,
              bookId: item.bookId,
              normalizedTitle: item.normalizedTitle,
              chapter: item.chapter,
            );
          }

          downloaded++;
          if (!controller.isClosed) {
            controller.add(
              DownloadProgress(downloaded: downloaded, total: total),
            );
          }
        });

        futures.add(future);
      }

      // Wait for all scheduled tasks (including those skipped by cancellation).
      await Future.wait(futures);

      if (!controller.isClosed) {
        if (_cancelled[translationId] == true) {
          controller.add(
            DownloadProgress(
              downloaded: downloaded,
              total: total,
              cancelled: true,
            ),
          );
        } else {
          controller.add(
            DownloadProgress(
              downloaded: downloaded,
              total: total,
              completed: true,
            ),
          );
        }
      }
    } catch (e) {
      final ctrl = _controllers[translationId];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(
          DownloadProgress(downloaded: 0, total: 0, error: e.toString()),
        );
      }
    } finally {
      _cleanup(translationId);
    }
  }

  /// Fetches a single chapter from the API and writes it to disk cache.
  static Future<void> _fetchAndCache({
    required String translationId,
    required int bookId,
    required String normalizedTitle,
    required int chapter,
  }) async {
    const baseUrl = 'https://bolls.life/get-text';

    try {
      final url = Uri.parse('$baseUrl/$translationId/$bookId/$chapter/');
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final verses = data
            .map((e) => SecondaryVerse.fromJson(e as Map<String, dynamic>))
            .toList();

        if (verses.isNotEmpty) {
          await VerseCacheService.cacheChapter(
            translationId: translationId,
            bookId: bookId,
            chapter: chapter,
            verses: verses,
          );

          // Also populate in-memory cache so the reading flow is instant.
          SecondaryBibleService.addToCache(
            translationId,
            bookId,
            chapter,
            verses,
          );
        }
      }
      // Silently skip chapters that return non-200 — fetched on-demand later.
    } catch (_) {
      // Network timeout or parse error: skip and continue.
    }
  }

  /// Loads all books from the bundled livros.json asset.
  static Future<List<_BookEntry>> _loadBooks() async {
    final raw = await rootBundle.loadString('assets/livros.json');
    final map = json.decode(raw) as Map<String, dynamic>;

    final entries = <_BookEntry>[];

    for (final testament in ['oldTestament', 'newTestament']) {
      final list = map[testament] as List;
      for (final item in list) {
        entries.add(
          _BookEntry(
            normalizedTitle: item['normalizedTitle'] as String,
            chaptersCount: item['chaptersCount'] as int,
          ),
        );
      }
    }

    return entries;
  }

  static void _cleanup(String translationId) {
    _controllers[translationId]?.close();
    _controllers.remove(translationId);
    _cancelled.remove(translationId);
  }
}
