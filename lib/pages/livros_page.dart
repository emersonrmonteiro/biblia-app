import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/language_config.dart';
import '../models/livro.dart';
import '../settings/language_settings_page.dart';
import 'capitulos_page.dart';
import 'search_page.dart';

class LivrosPage extends StatefulWidget {
  final void Function(BuildContext) onToggleTheme;
  final LanguageConfig languageConfig;
  final void Function(LanguageConfig) onChangeLanguageConfig;

  const LivrosPage({
    super.key,
    required this.onToggleTheme,
    required this.languageConfig,
    required this.onChangeLanguageConfig,
  });

  @override
  State<LivrosPage> createState() => _LivrosPageState();
}

class _LivrosPageState extends State<LivrosPage> {
  List<Livro> velhoTestamento = [];
  List<Livro> novoTestamento = [];

  // Collapse state — both expanded by default.
  bool _velhoExpanded = true;
  bool _novoExpanded = true;

  @override
  void initState() {
    super.initState();
    carregarLivros();
  }

  Future<void> carregarLivros() async {
    final data = await rootBundle.loadString('assets/livros.json');
    final jsonResult = json.decode(data);

    setState(() {
      velhoTestamento = (jsonResult['oldTestament'] as List)
          .map((e) => Livro.fromJson(e, 'velho'))
          .toList();

      novoTestamento = (jsonResult['newTestament'] as List)
          .map((e) => Livro.fromJson(e, 'novo'))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryTranslation = widget.languageConfig.primaryTranslation;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Bíblia'),
            Text(
              primaryTranslation.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate_rounded),
            tooltip: 'Idiomas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LanguageSettingsPage(
                    currentConfig: widget.languageConfig,
                    onApply: (config) {
                      widget.onChangeLanguageConfig(config);
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Buscar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchPage(
                    onToggleTheme: widget.onToggleTheme,
                    languageConfig: widget.languageConfig,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Aparência',
            onPressed: () => widget.onToggleTheme(context),
          ),
        ],
      ),
      body: velhoTestamento.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildTestamentoSection(
                  titulo: 'Velho Testamento',
                  subtitulo: '39 livros',
                  livros: velhoTestamento,
                  expanded: _velhoExpanded,
                  onToggle: () =>
                      setState(() => _velhoExpanded = !_velhoExpanded),
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 12),
                _buildTestamentoSection(
                  titulo: 'Novo Testamento',
                  subtitulo: '27 livros',
                  livros: novoTestamento,
                  expanded: _novoExpanded,
                  onToggle: () =>
                      setState(() => _novoExpanded = !_novoExpanded),
                  colorScheme: colorScheme,
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section with collapsible grid
  // ---------------------------------------------------------------------------

  Widget _buildTestamentoSection({
    required String titulo,
    required String subtitulo,
    required List<Livro> livros,
    required bool expanded,
    required VoidCallback onToggle,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header — tappable to expand/collapse
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Animated grid
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _buildLivrosGrid(livros, colorScheme),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Books grid
  // ---------------------------------------------------------------------------

  Widget _buildLivrosGrid(List<Livro> livros, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.2,
        ),
        itemCount: livros.length,
        itemBuilder: (context, index) {
          final livro = livros[index];
          return _buildLivroCard(livro, colorScheme);
        },
      ),
    );
  }

  Widget _buildLivroCard(Livro livro, ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surfaceContainerHighest.withAlpha(130),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CapitulosPage(
                livro: livro,
                onToggleTheme: widget.onToggleTheme,
                languageConfig: widget.languageConfig,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                livro.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${livro.chaptersCount} cap.',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
