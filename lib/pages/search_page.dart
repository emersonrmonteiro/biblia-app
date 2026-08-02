import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/language_config.dart';
import '../models/livro.dart';
import '../models/search_result.dart';
import '../services/bible_search_service.dart';
import 'versiculos_page.dart';

class SearchPage extends StatefulWidget {
  final void Function(BuildContext) onToggleTheme;
  final LanguageConfig languageConfig;

  const SearchPage({
    super.key,
    required this.onToggleTheme,
    required this.languageConfig,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  List<Livro> _livros = [];

  @override
  void initState() {
    super.initState();
    _carregarLivros();
  }

  Future<void> _carregarLivros() async {
    final data = await rootBundle.loadString('assets/livros.json');
    final jsonResult = json.decode(data);

    setState(() {
      _livros = [
        ...(jsonResult['oldTestament'] as List).map(
          (e) => Livro.fromJson(e, 'velho'),
        ),
        ...(jsonResult['newTestament'] as List).map(
          (e) => Livro.fromJson(e, 'novo'),
        ),
      ];
    });
  }

  Future<void> _performSearch() async {
    final query = _controller.text.trim();
    if (query.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite pelo menos 3 caracteres')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final results = await BibleSearchService.search(
      query,
      widget.languageConfig.primaryTranslation,
      _livros,
    );

    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        actions: [
          // Badge showing which translation is being searched
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.languageConfig.primaryTranslation.abbreviation,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'Buscar nos versículos...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _results = [];
                      _hasSearched = false;
                    });
                  },
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Buscando em todos os livros...'),
                  ],
                ),
              ),
            )
          else if (_hasSearched && _results.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Nenhum resultado encontrado',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${_results.length} resultado${_results.length > 1 ? 's' : ''} encontrado${_results.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (!_isLoading && _results.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return _buildResultTile(result);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultTile(SearchResult result) {
    final query = _controller.text.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${result.livro.title} ${result.capitulo}:${result.verseNumber}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _highlightText(result.verseContent, query),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VersiculosPage(
              livro: result.livro,
              capitulo: result.capitulo,
              onToggleTheme: widget.onToggleTheme,
              languageConfig: widget.languageConfig,
            ),
          ),
        );
      },
    );
  }

  Widget _highlightText(String text, String query) {
    if (query.isEmpty) {
      return Text(text, maxLines: 3, overflow: TextOverflow.ellipsis);
    }

    final normalizedText = _normalize(text);
    final normalizedQuery = _normalize(query);
    final startIndex = normalizedText.indexOf(normalizedQuery);

    if (startIndex == -1) {
      return Text(text, maxLines: 3, overflow: TextOverflow.ellipsis);
    }

    final endIndex = startIndex + query.length;

    final contextStart = (startIndex - 40).clamp(0, text.length);
    final contextEnd = (endIndex + 80).clamp(0, text.length);
    final prefix = contextStart > 0 ? '...' : '';
    final suffix = contextEnd < text.length ? '...' : '';

    final before = text.substring(contextStart, startIndex);
    final match = text.substring(startIndex, endIndex);
    final after = text.substring(endIndex, contextEnd);

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
        children: [
          TextSpan(text: '$prefix$before'),
          TextSpan(
            text: match,
            style: TextStyle(
              backgroundColor: Colors.yellow.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: '$after$suffix'),
        ],
      ),
    );
  }

  String _normalize(String text) {
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
