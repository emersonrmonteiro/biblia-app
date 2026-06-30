class Livro {
  final String title;
  final String normalizedTitle;
  final int chaptersCount;
  final String testament;

  Livro({
    required this.title,
    required this.normalizedTitle,
    required this.chaptersCount,
    required this.testament,
  });

  factory Livro.fromJson(Map<String, dynamic> json, String testament) {
    return Livro(
      title: json['title'],
      normalizedTitle: json['normalizedTitle'],
      chaptersCount: json['chaptersCount'],
      testament: testament,
    );
  }
}
