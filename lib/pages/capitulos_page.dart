import 'package:biblia_app/models/bible_version.dart';
import 'package:biblia_app/models/livro.dart';
import 'package:flutter/material.dart';

import 'versiculos_page.dart';

class CapitulosPage extends StatelessWidget {
  final Livro livro;
  final BibleVersion selectedVersion;
  final void Function(BuildContext) onToggleTheme;

  const CapitulosPage({
    super.key,
    required this.livro,
    required this.selectedVersion,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Capítulos de ${livro.title}"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => onToggleTheme(context),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: livro.chaptersCount,
        itemBuilder: (context, index) {
          final capitulo = index + 1;
          return ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VersiculosPage(
                    livro: livro,
                    capitulo: capitulo,
                    selectedVersion: selectedVersion,
                    onToggleTheme: onToggleTheme,
                  ),
                ),
              );
            },
            child: Text('$capitulo'),
          );
        },
      ),
    );
  }
}
