import 'livro.dart';

class SearchResult {
  final Livro livro;
  final int capitulo;
  final String verseNumber;
  final String verseContent;
  final String verseTitle;

  SearchResult({
    required this.livro,
    required this.capitulo,
    required this.verseNumber,
    required this.verseContent,
    this.verseTitle = '',
  });
}
