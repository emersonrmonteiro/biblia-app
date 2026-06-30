import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bible_version.dart';
import '../models/livro.dart';
import 'capitulos_page.dart';

class LivrosPage extends StatefulWidget {
  final BibleVersion selectedVersion;
  final Future<void> Function(BibleVersion) onChangeVersion;
  final void Function(BuildContext) onToggleTheme;

  const LivrosPage({
    super.key,
    required this.selectedVersion,
    required this.onChangeVersion,
    required this.onToggleTheme,
  });

  @override
  State<LivrosPage> createState() => _LivrosPageState();
}

class _LivrosPageState extends State<LivrosPage> {
  List<Livro> velhoTestamento = [];
  List<Livro> novoTestamento = [];

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
    return Scaffold(
      appBar: AppBar(
        title: Text("Bíblia - ${widget.selectedVersion.name}"),
        centerTitle: true,
        actions: [
          if (availableVersions.length > 1)
            PopupMenuButton<BibleVersion>(
              icon: const Icon(Icons.book),
              tooltip: 'Versão da Bíblia',
              onSelected: (version) {
                widget.onChangeVersion(version);
              },
              itemBuilder: (context) {
                return availableVersions.map((version) {
                  return PopupMenuItem<BibleVersion>(
                    value: version,
                    child: Row(
                      children: [
                        if (version.id == widget.selectedVersion.id)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text('${version.name} (${version.abbreviation})'),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => widget.onToggleTheme(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildGrupo("Velho Testamento", velhoTestamento),
          _buildGrupo("Novo Testamento", novoTestamento),
        ],
      ),
    );
  }

  Widget _buildGrupo(String titulo, List<Livro> livros) {
    return ExpansionTile(
      title: Text(titulo),
      children: livros.map((livro) {
        return ListTile(
          title: Text(livro.title),
          subtitle: Text("Capítulos: ${livro.chaptersCount}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CapitulosPage(
                  livro: livro,
                  selectedVersion: widget.selectedVersion,
                  onToggleTheme: widget.onToggleTheme,
                ),
              ),
            );
          },
          trailing: const Icon(Icons.arrow_right),
        );
      }).toList(),
    );
  }
}
