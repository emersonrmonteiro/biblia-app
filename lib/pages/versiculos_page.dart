import 'dart:convert';

import 'package:biblia_app/models/bible_version.dart';
import 'package:biblia_app/models/livro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/versiculo.dart';

class VersiculosPage extends StatefulWidget {
  final Livro livro;
  final int capitulo;
  final BibleVersion selectedVersion;
  final void Function(BuildContext) onToggleTheme;

  const VersiculosPage({
    super.key,
    required this.livro,
    required this.capitulo,
    required this.selectedVersion,
    required this.onToggleTheme,
  });

  @override
  State<VersiculosPage> createState() => _VersiculosPageState();
}

class _VersiculosPageState extends State<VersiculosPage> {
  List<Versiculo> versiculos = [];

  @override
  void initState() {
    super.initState();
    carregarCapitulo();
  }

  Future<void> carregarCapitulo() async {
    final path =
        '${widget.selectedVersion.assetPath}/${widget.livro.testament}-testamento/${widget.livro.normalizedTitle}/${widget.capitulo}.json';
    final content = await rootBundle.loadString(path);
    final data = json.decode(content) as List;
    setState(() {
      versiculos = data.map((e) => Versiculo.fromJson(e)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = widget.capitulo == 1;
    final isLast = widget.capitulo == widget.livro.chaptersCount;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => widget.onToggleTheme(context),
          ),
        ],
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              child: Text(widget.livro.title),
              onTap: () => Navigator.popUntil(context, (route) => false),
            ),
            Text(' | '),
            GestureDetector(
              child: Text('Capítulo ${widget.capitulo}'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: versiculos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: versiculos.length,
              itemBuilder: (context, index) {
                final v = versiculos[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (v.title.isNotEmpty)
                        Center(
                          child: Text(
                            v.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      RichText(
                        textAlign: TextAlign.justify,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${v.number} ',
                              style: DefaultTextStyle.of(context).style
                                  .copyWith(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            TextSpan(
                              text: v.content,
                              style: DefaultTextStyle.of(
                                context,
                              ).style.copyWith(fontSize: 16, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: isFirst
                  ? null
                  : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VersiculosPage(
                            livro: widget.livro,
                            capitulo: widget.capitulo - 1,
                            selectedVersion: widget.selectedVersion,
                            onToggleTheme: widget.onToggleTheme,
                          ),
                        ),
                      );
                    },
              child: const Text("Anterior"),
            ),
            Text(
              "${widget.capitulo}/${widget.livro.chaptersCount}",
              style: const TextStyle(fontSize: 16),
            ),
            ElevatedButton(
              onPressed: isLast
                  ? null
                  : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VersiculosPage(
                            livro: widget.livro,
                            capitulo: widget.capitulo + 1,
                            selectedVersion: widget.selectedVersion,
                            onToggleTheme: widget.onToggleTheme,
                          ),
                        ),
                      );
                    },
              child: const Text("Próximo"),
            ),
          ],
        ),
      ),
    );
  }
}
