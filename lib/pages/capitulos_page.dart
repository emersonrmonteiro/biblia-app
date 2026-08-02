import 'package:biblia_app/models/language_config.dart';
import 'package:biblia_app/models/livro.dart';
import 'package:flutter/material.dart';

import 'versiculos_page.dart';

class CapitulosPage extends StatelessWidget {
  final Livro livro;
  final void Function(BuildContext) onToggleTheme;
  final LanguageConfig languageConfig;

  const CapitulosPage({
    super.key,
    required this.livro,
    required this.onToggleTheme,
    required this.languageConfig,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(livro.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 4),
              child: Text(
                'Selecione um capítulo',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.1,
                ),
                itemCount: livro.chaptersCount,
                itemBuilder: (context, index) {
                  final capitulo = index + 1;
                  return Material(
                    color: colorScheme.surfaceContainerHighest.withAlpha(120),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VersiculosPage(
                              livro: livro,
                              capitulo: capitulo,
                              onToggleTheme: onToggleTheme,
                              languageConfig: languageConfig,
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: Text(
                          '$capitulo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
