import 'package:biblia_app/models/language_config.dart';
import 'package:biblia_app/models/livro.dart';
import 'package:flutter/material.dart';

import '../models/versiculo.dart';
import '../services/language_service.dart';
import '../services/primary_bible_service.dart';
import '../services/reading_preferences_service.dart';
import '../services/secondary_bible_service.dart';
import '../services/translation_service.dart';
import '../settings/language_settings_page.dart';

class VersiculosPage extends StatefulWidget {
  final Livro livro;
  final int capitulo;
  final void Function(BuildContext) onToggleTheme;
  final LanguageConfig languageConfig;

  const VersiculosPage({
    super.key,
    required this.livro,
    required this.capitulo,
    required this.onToggleTheme,
    required this.languageConfig,
  });

  @override
  State<VersiculosPage> createState() => _VersiculosPageState();
}

class _VersiculosPageState extends State<VersiculosPage> {
  List<Versiculo> _versiculos = [];
  // Maps verse number → secondary text. Populated when dual-language is on.
  final Map<String, String> _secondaryVerses = {};
  bool _showDualLanguage = false;
  bool _loadingSecondary = false;
  OverlayEntry? _overlayEntry;

  // Mutable language config — can be updated inline without leaving the page.
  late LanguageConfig _languageConfig;

  @override
  void initState() {
    super.initState();
    _languageConfig = widget.languageConfig;
    _loadPrefsAndChapter();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadPrefsAndChapter() async {
    final showDual = await ReadingPreferencesService.getShowDualLanguage();
    if (mounted) {
      setState(() => _showDualLanguage = showDual);
    }
    await _loadPrimaryChapter();
    if (_showDualLanguage) {
      await _loadSecondaryChapter();
    }
  }

  Future<void> _loadPrimaryChapter() async {
    final primary = _languageConfig.primaryTranslation;
    debugPrint('=== Carregando capítulo — tradução: ${primary.id}');

    final result = await PrimaryBibleService.getChapter(
      translation: primary,
      testament: widget.livro.testament,
      normalizedTitle: widget.livro.normalizedTitle,
      chapter: widget.capitulo,
    );

    debugPrint('=== Versículos carregados: ${result.length}');

    if (mounted) {
      setState(() => _versiculos = result);
    }

    // Pre-warm next chapter in background.
    if (widget.capitulo < widget.livro.chaptersCount) {
      PrimaryBibleService.prefetch(
        translation: primary,
        normalizedTitle: widget.livro.normalizedTitle,
        chapter: widget.capitulo + 1,
      );
    }
  }

  Future<void> _loadSecondaryChapter() async {
    if (!mounted) return;
    setState(() => _loadingSecondary = true);

    final secondary = _languageConfig.secondaryTranslation;
    final verses = await SecondaryBibleService.getChapter(
      translationId: secondary.id,
      normalizedTitle: widget.livro.normalizedTitle,
      chapter: widget.capitulo,
    );

    if (mounted) {
      setState(() {
        _secondaryVerses.clear();
        for (final v in verses) {
          _secondaryVerses[v.verse.toString()] = v.text;
        }
        _loadingSecondary = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Overlay helpers
  // ---------------------------------------------------------------------------

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ---------------------------------------------------------------------------
  // Word tap → translation popup
  // ---------------------------------------------------------------------------

  Future<void> _onWordTap(String word, Offset globalPosition) async {
    _removeOverlay();

    final sourceLang = LanguageService.getLanguageCode(
      _languageConfig.primaryTranslation,
    );
    final targetLang = LanguageService.getLanguageCode(
      _languageConfig.secondaryTranslation,
    );

    _showTranslationPopup(
      globalPosition: globalPosition,
      word: word,
      translation: null,
      isLoading: true,
    );

    final result = await TranslationService.translate(
      text: word,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );

    _removeOverlay();
    if (mounted) {
      _showTranslationPopup(
        globalPosition: globalPosition,
        word: word,
        translation: result.source == TranslationSource.notFound
            ? null
            : result.translated,
        isLoading: false,
        source: result.source,
      );
    }
  }

  void _showTranslationPopup({
    required Offset globalPosition,
    required String word,
    required String? translation,
    required bool isLoading,
    TranslationSource? source,
  }) {
    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => _TranslationPopup(
        globalPosition: globalPosition,
        word: word,
        translation: translation,
        isLoading: isLoading,
        source: source,
        onDismiss: _removeOverlay,
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  // ---------------------------------------------------------------------------
  // Long-press → secondary verse bottom sheet
  // ---------------------------------------------------------------------------

  Future<void> _onVerseLongPress(Versiculo v) async {
    _removeOverlay();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _SecondaryVerseSheet(
        versiculo: v,
        livro: widget.livro,
        capitulo: widget.capitulo,
        secondaryTranslation: _languageConfig.secondaryTranslation,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chapter picker bottom sheet
  // ---------------------------------------------------------------------------

  void _showChapterPicker() {
    _removeOverlay();
    final colorScheme = Theme.of(context).colorScheme;
    final totalChapters = widget.livro.chaptersCount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Handle + header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.livro.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· $totalChapters capítulos',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Grid
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.1,
                        ),
                    itemCount: totalChapters,
                    itemBuilder: (_, index) {
                      final cap = index + 1;
                      final isCurrent = cap == widget.capitulo;
                      return Material(
                        color: isCurrent
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest.withAlpha(
                                120,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            if (cap == widget.capitulo) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VersiculosPage(
                                  livro: widget.livro,
                                  capitulo: cap,
                                  onToggleTheme: widget.onToggleTheme,
                                  languageConfig: _languageConfig,
                                ),
                              ),
                            );
                          },
                          child: Center(
                            child: Text(
                              '$cap',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isCurrent
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openLanguageSettings() async {
    _removeOverlay();

    final result = await Navigator.push<LanguageConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => LanguageSettingsPage(
          currentConfig: _languageConfig,
          onApply: (config) => Navigator.pop(context, config),
        ),
      ),
    );

    if (result == null || !mounted) return;

    final primaryChanged =
        result.primaryTranslation.id != _languageConfig.primaryTranslation.id;
    final secondaryChanged =
        result.secondaryTranslation.id !=
        _languageConfig.secondaryTranslation.id;

    setState(() {
      _languageConfig = result;
      if (primaryChanged) {
        _versiculos = [];
        _secondaryVerses.clear();
      } else if (secondaryChanged) {
        _secondaryVerses.clear();
      }
    });

    if (primaryChanged) await _loadPrimaryChapter();
    if (_showDualLanguage && (primaryChanged || secondaryChanged)) {
      await _loadSecondaryChapter();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isFirst = widget.capitulo == 1;
    final isLast = widget.capitulo == widget.livro.chaptersCount;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Book name — tap to go back to book list
            GestureDetector(
              onTap: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(
                widget.livro.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '·',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            // Chapter label — tap to open chapter picker
            GestureDetector(
              onTap: _showChapterPicker,
              child: Text(
                'Cap. ${widget.capitulo}',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: colorScheme.primary.withAlpha(120),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Active translation badge — tap to open language settings
          Tooltip(
            message: 'Trocar idioma',
            child: GestureDetector(
              onTap: _openLanguageSettings,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _languageConfig.primaryTranslation.abbreviation,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        if (_showDualLanguage) ...[
                          Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onPrimaryContainer.withAlpha(
                                160,
                              ),
                            ),
                          ),
                          Text(
                            _languageConfig.secondaryTranslation.abbreviation,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: colorScheme.onPrimaryContainer.withAlpha(
                                200,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 14,
                          color: colorScheme.onPrimaryContainer.withAlpha(180),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => widget.onToggleTheme(context),
          ),
        ],
      ),
      body: _versiculos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: _versiculos.length,
                itemBuilder: (context, index) {
                  final v = _versiculos[index];
                  return GestureDetector(
                    onLongPress: () => _onVerseLongPress(v),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (v.title.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Center(
                                child: Text(
                                  v.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          _buildTappableVerse(v),
                          if (_showDualLanguage) _buildSecondaryVerse(v.number),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: _buildBottomNav(isFirst, isLast),
    );
  }

  // ---------------------------------------------------------------------------
  // Verse widgets
  // ---------------------------------------------------------------------------

  Widget _buildTappableVerse(Versiculo v) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final verseNumSize = (bodyStyle.fontSize ?? 16) - 3;

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: [
        // Verse number
        Text(
          '${v.number} ',
          style: TextStyle(
            fontSize: verseNumSize,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary.withAlpha(180),
          ),
        ),
        // Each word — tappable for translation popup
        ...v.content.split(' ').map((word) {
          return GestureDetector(
            onTapUp: (details) => _onWordTap(word, details.globalPosition),
            child: Text('$word ', style: bodyStyle.copyWith(height: 1.8)),
          );
        }),
      ],
    );
  }

  Widget _buildSecondaryVerse(String verseNumber) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final secondaryFontSize = (bodyStyle.fontSize ?? 16) - 2;
    final secondaryAbbr = _languageConfig.secondaryTranslation.abbreviation;

    // Still loading
    if (_loadingSecondary) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 6),
            Text(
              'carregando $secondaryAbbr…',
              style: TextStyle(
                fontSize: secondaryFontSize,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
      );
    }

    final text = _secondaryVerses[verseNumber];
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: secondaryFontSize,
          height: 1.6,
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurface.withAlpha(140),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom nav
  // ---------------------------------------------------------------------------

  Widget _buildBottomNav(bool isFirst, bool isLast) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Previous button
            Expanded(
              child: isFirst
                  ? const SizedBox()
                  : TextButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VersiculosPage(
                              livro: widget.livro,
                              capitulo: widget.capitulo - 1,
                              onToggleTheme: widget.onToggleTheme,
                              languageConfig: _languageConfig,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Anterior'),
                    ),
            ),
            // Page indicator — tap to open chapter picker
            GestureDetector(
              onTap: _showChapterPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.capitulo} / ${widget.livro.chaptersCount}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            // Next button
            Expanded(
              child: isLast
                  ? const SizedBox()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VersiculosPage(
                                  livro: widget.livro,
                                  capitulo: widget.capitulo + 1,
                                  onToggleTheme: widget.onToggleTheme,
                                  languageConfig: _languageConfig,
                                ),
                              ),
                            );
                          },
                          icon: const Text('Próximo'),
                          label: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Translation word popup
// =============================================================================

class _TranslationPopup extends StatelessWidget {
  final Offset globalPosition;
  final String word;
  final String? translation;
  final bool isLoading;
  final TranslationSource? source;
  final VoidCallback onDismiss;

  const _TranslationPopup({
    required this.globalPosition,
    required this.word,
    required this.translation,
    required this.isLoading,
    this.source,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    const popupWidth = 200.0;
    const popupHeight = 70.0;

    double left = globalPosition.dx - popupWidth / 2;
    double top = globalPosition.dy - popupHeight - 16;

    if (left < 8) left = 8;
    if (left + popupWidth > screenSize.width - 8) {
      left = screenSize.width - popupWidth - 8;
    }
    if (top < 8) top = globalPosition.dy + 24;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 120,
                maxWidth: popupWidth,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Traduzindo...'),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          translation ?? 'Tradução não encontrada',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: translation != null ? null : Colors.red[400],
                          ),
                        ),
                        if (source != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            source == TranslationSource.api
                                ? '· online'
                                : '· offline',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Secondary verse bottom sheet (long-press)
// =============================================================================

class _SecondaryVerseSheet extends StatefulWidget {
  final Versiculo versiculo;
  final Livro livro;
  final int capitulo;
  final BibleTranslation secondaryTranslation;

  const _SecondaryVerseSheet({
    required this.versiculo,
    required this.livro,
    required this.capitulo,
    required this.secondaryTranslation,
  });

  @override
  State<_SecondaryVerseSheet> createState() => _SecondaryVerseSheetState();
}

class _SecondaryVerseSheetState extends State<_SecondaryVerseSheet> {
  String? _translatedText;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSecondaryVerse();
  }

  Future<void> _fetchSecondaryVerse() async {
    final verse = await SecondaryBibleService.getVerse(
      translationId: widget.secondaryTranslation.id,
      normalizedTitle: widget.livro.normalizedTitle,
      chapter: widget.capitulo,
      verseNumber: widget.versiculo.number,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (verse != null) {
          _translatedText = verse.text;
        } else {
          _error =
              'Não foi possível carregar o versículo.\nVerifique sua conexão.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              Icon(
                Icons.translate,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.livro.title} ${widget.capitulo}:${widget.versiculo.number}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.secondaryTranslation.abbreviation,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off, size: 32, color: Colors.grey[500]),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Original verse
            Text(
              widget.versiculo.content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
            const Divider(height: 24),
            // Secondary verse
            Text(
              _translatedText!,
              style: const TextStyle(fontSize: 18, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}
