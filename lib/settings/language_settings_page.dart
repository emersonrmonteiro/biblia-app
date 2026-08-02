import 'dart:async';

import 'package:flutter/material.dart';

import '../models/language_config.dart';
import '../services/bible_download_service.dart';
import '../services/language_service.dart';
import '../services/verse_cache_service.dart';

// Total number of Bible chapters (39 OT + 27 NT books = 1189 chapters).
const int _kTotalChapters = 1189;

class LanguageSettingsPage extends StatefulWidget {
  final LanguageConfig currentConfig;
  final void Function(LanguageConfig) onApply;

  const LanguageSettingsPage({
    super.key,
    required this.currentConfig,
    required this.onApply,
  });

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  late BibleTranslation _primaryTranslation;
  late BibleTranslation _secondaryTranslation;

  // Download progress per translationId.
  final Map<String, DownloadProgress> _downloadProgress = {};
  final Map<String, StreamSubscription<DownloadProgress>> _subscriptions = {};

  // Cached chapter counts per translationId (loaded once on init).
  final Map<String, int> _cachedChapters = {};

  @override
  void initState() {
    super.initState();
    _primaryTranslation = widget.currentConfig.primaryTranslation;
    _secondaryTranslation = widget.currentConfig.secondaryTranslation;
    _loadCachedCounts();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Data loading
  // -------------------------------------------------------------------------

  Future<void> _loadCachedCounts() async {
    for (final lang in availableLanguages) {
      for (final translation in lang.translations) {
        if (translation.isLocal) continue;
        final count = await VerseCacheService.countCachedChapters(
          translation.id,
        );
        if (mounted) {
          setState(() {
            _cachedChapters[translation.id] = count;
          });
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Download management
  // -------------------------------------------------------------------------

  void _startDownload(BibleTranslation translation) {
    if (BibleDownloadService.isDownloading(translation.id)) return;

    final stream = BibleDownloadService.downloadTranslation(translation.id);
    final sub = stream.listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _downloadProgress[translation.id] = progress;
          if (progress.completed) {
            _cachedChapters[translation.id] = progress.total;
          }
        });
      },
      onDone: () {
        _subscriptions.remove(translation.id);
      },
    );
    _subscriptions[translation.id] = sub;

    setState(() {
      _downloadProgress[translation.id] = const DownloadProgress(
        downloaded: 0,
        total: _kTotalChapters,
      );
    });
  }

  void _cancelDownload(BibleTranslation translation) {
    BibleDownloadService.cancelDownload(translation.id);
  }

  Future<void> _deleteOfflineData(BibleTranslation translation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover dados offline'),
        content: Text(
          'Deseja remover os dados offline de "${translation.name}"?\n\n'
          'A versão continuará disponível com conexão à internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await VerseCacheService.deleteTranslation(translation.id);
      if (mounted) {
        setState(() {
          _cachedChapters[translation.id] = 0;
          _downloadProgress.remove(translation.id);
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final primaryLang = _getLanguageForTranslation(_primaryTranslation);
    final secondaryLang = _getLanguageForTranslation(_secondaryTranslation);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Idiomas'), centerTitle: true),
      // ── Fixed bottom bar with Apply button ──────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant.withAlpha(60)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.check),
              label: const Text('Aplicar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Primary language ───────────────────────────────────────────────
          _buildSectionHeader(
            icon: Icons.menu_book,
            title: 'Idioma Principal (Leitura)',
            subtitle: 'Versão que você lê normalmente',
          ),
          const SizedBox(height: 8),
          _buildLanguageSelector(
            currentLanguage: primaryLang,
            currentTranslation: _primaryTranslation,
            onLanguageChanged: (lang) {
              setState(() => _primaryTranslation = lang.translations.first);
            },
            onTranslationChanged: (translation) {
              setState(() => _primaryTranslation = translation);
            },
          ),

          // ── Swap button ────────────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Tooltip(
                message: 'Trocar idiomas',
                child: InkWell(
                  onTap: () {
                    setState(() {
                      final tmp = _primaryTranslation;
                      _primaryTranslation = _secondaryTranslation;
                      _secondaryTranslation = tmp;
                    });
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _primaryTranslation.abbreviation,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.swap_vert_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          _secondaryTranslation.abbreviation,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Secondary language ─────────────────────────────────────────────
          _buildSectionHeader(
            icon: Icons.translate,
            title: 'Idioma Secundário (Aprendizado)',
            subtitle: 'Idioma que você quer aprender',
          ),
          const SizedBox(height: 8),
          _buildLanguageSelector(
            currentLanguage: secondaryLang,
            currentTranslation: _secondaryTranslation,
            onLanguageChanged: (lang) {
              setState(() => _secondaryTranslation = lang.translations.first);
            },
            onTranslationChanged: (translation) {
              setState(() => _secondaryTranslation = translation);
            },
          ),

          const SizedBox(height: 32),

          _buildOfflineManagerSection(),

          const SizedBox(height: 32),

          // ── How to use card ────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Como usar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('• Toque em uma palavra para ver a tradução'),
                  const SizedBox(height: 4),
                  const Text(
                    '• Segure pressionado para ver o versículo completo no idioma secundário',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Offline manager section
  // -------------------------------------------------------------------------

  Widget _buildOfflineManagerSection() {
    // Collect all non-local translations.
    final apiTranslations = <BibleTranslation>[];
    for (final lang in availableLanguages) {
      for (final t in lang.translations) {
        if (!t.isLocal) apiTranslations.add(t);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.cloud_download_outlined,
          title: 'Versões offline',
          subtitle: 'Baixe versões para ler sem internet',
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (int i = 0; i < apiTranslations.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildTranslationDownloadTile(apiTranslations[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationDownloadTile(BibleTranslation translation) {
    final progress = _downloadProgress[translation.id];
    final cachedCount = _cachedChapters[translation.id] ?? 0;
    final isDownloading = progress != null && progress.isActive;
    final isFullyDownloaded = !isDownloading && cachedCount >= _kTotalChapters;
    final hasPartialData =
        !isDownloading && cachedCount > 0 && !isFullyDownloaded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status icon
              _buildStatusIcon(
                isFullyDownloaded: isFullyDownloaded,
                isDownloading: isDownloading,
                hasPartialData: hasPartialData,
              ),
              const SizedBox(width: 12),

              // Name and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${translation.name} (${translation.abbreviation})',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    _buildStatusLabel(
                      isFullyDownloaded: isFullyDownloaded,
                      isDownloading: isDownloading,
                      hasPartialData: hasPartialData,
                      progress: progress,
                      cachedCount: cachedCount,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Action button
              _buildActionButton(
                translation: translation,
                isDownloading: isDownloading,
                isFullyDownloaded: isFullyDownloaded,
                hasPartialData: hasPartialData,
              ),
            ],
          ),

          // Progress bar (only while downloading)
          if (isDownloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 6,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.downloaded} de ${progress.total} capítulos',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  '${(progress.fraction * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],

          // Error message
          if (progress?.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 14, color: Colors.red[700]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Erro ao baixar. Tente novamente.',
                      style: TextStyle(fontSize: 11, color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon({
    required bool isFullyDownloaded,
    required bool isDownloading,
    required bool hasPartialData,
  }) {
    if (isFullyDownloaded) {
      return Icon(Icons.offline_pin, color: Colors.green[700], size: 22);
    }
    if (isDownloading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    if (hasPartialData) {
      return Icon(
        Icons.download_done_outlined,
        color: Colors.orange[700],
        size: 22,
      );
    }
    return Icon(Icons.cloud_outlined, color: Colors.grey[500], size: 22);
  }

  Widget _buildStatusLabel({
    required bool isFullyDownloaded,
    required bool isDownloading,
    required bool hasPartialData,
    required DownloadProgress? progress,
    required int cachedCount,
  }) {
    if (isFullyDownloaded) {
      return Text(
        'Disponível offline',
        style: TextStyle(fontSize: 12, color: Colors.green[700]),
      );
    }
    if (isDownloading) {
      return Text(
        'Baixando…',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    if (hasPartialData) {
      return Text(
        'Parcial — $cachedCount de $_kTotalChapters capítulos',
        style: TextStyle(fontSize: 12, color: Colors.orange[700]),
      );
    }
    if (progress?.cancelled == true) {
      return Text(
        'Download cancelado',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      );
    }
    return Text(
      'Requer internet',
      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
    );
  }

  Widget _buildActionButton({
    required BibleTranslation translation,
    required bool isDownloading,
    required bool isFullyDownloaded,
    required bool hasPartialData,
  }) {
    if (isDownloading) {
      return TextButton.icon(
        onPressed: () => _cancelDownload(translation),
        icon: const Icon(Icons.stop_circle_outlined, size: 18),
        label: const Text('Parar'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (isFullyDownloaded) {
      return IconButton(
        onPressed: () => _deleteOfflineData(translation),
        icon: const Icon(Icons.delete_outline, size: 20),
        tooltip: 'Remover dados offline',
        color: Colors.grey[600],
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );
    }

    // Not downloaded or partial — show download button.
    return TextButton.icon(
      onPressed: () => _startDownload(translation),
      icon: const Icon(Icons.download_outlined, size: 18),
      label: Text(hasPartialData ? 'Continuar' : 'Baixar'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Language selector (unchanged logic, extracted widget)
  // -------------------------------------------------------------------------

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector({
    required BibleLanguage currentLanguage,
    required BibleTranslation currentTranslation,
    required void Function(BibleLanguage) onLanguageChanged,
    required void Function(BibleTranslation) onTranslationChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: currentLanguage.code,
              decoration: const InputDecoration(
                labelText: 'Idioma',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: availableLanguages.map((lang) {
                return DropdownMenuItem(
                  value: lang.code,
                  child: Text(lang.name),
                );
              }).toList(),
              onChanged: (code) {
                if (code != null) {
                  final lang = availableLanguages.firstWhere(
                    (l) => l.code == code,
                  );
                  onLanguageChanged(lang);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: currentTranslation.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Versão',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: currentLanguage.translations.map((t) {
                return DropdownMenuItem(
                  value: t.id,
                  child: Text(
                    '${t.name} (${t.abbreviation})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null) {
                  final translation = currentLanguage.translations.firstWhere(
                    (t) => t.id == id,
                  );
                  onTranslationChanged(translation);
                }
              },
            ),
            if (currentTranslation.isLocal)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.offline_pin, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Disponível offline',
                      style: TextStyle(fontSize: 12, color: Colors.green[700]),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildInlineDownloadHint(currentTranslation),
              ),
          ],
        ),
      ),
    );
  }

  /// Small inline hint shown below the version dropdown when it is not local.
  /// Shows "offline" badge if downloaded, or a quick-download link otherwise.
  Widget _buildInlineDownloadHint(BibleTranslation translation) {
    final progress = _downloadProgress[translation.id];
    final cachedCount = _cachedChapters[translation.id] ?? 0;
    final isDownloading = progress != null && progress.isActive;
    final isFullyDownloaded = !isDownloading && cachedCount >= _kTotalChapters;

    if (isFullyDownloaded) {
      return Row(
        children: [
          Icon(Icons.offline_pin, size: 16, color: Colors.green[700]),
          const SizedBox(width: 4),
          Text(
            'Disponível offline',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          ),
        ],
      );
    }

    if (isDownloading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.fraction,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Baixando… ${(progress.fraction * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.cloud_outlined, size: 16, color: Colors.blue[700]),
        const SizedBox(width: 4),
        Text(
          'Requer internet — ',
          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
        ),
        GestureDetector(
          onTap: () => _startDownload(translation),
          child: Text(
            'baixar para uso offline',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  BibleLanguage _getLanguageForTranslation(BibleTranslation translation) {
    for (final lang in availableLanguages) {
      if (lang.translations.any((t) => t.id == translation.id)) {
        return lang;
      }
    }
    return availableLanguages.first;
  }

  void _apply() {
    final config = LanguageConfig(
      primaryTranslation: _primaryTranslation,
      secondaryTranslation: _secondaryTranslation,
    );
    LanguageService.saveLanguageConfig(config);
    widget.onApply(config);
  }
}
