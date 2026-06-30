class Versiculo {
  final String title;
  final String number;
  final String content;

  Versiculo({required this.title, required this.number, required this.content});

  factory Versiculo.fromJson(Map<String, dynamic> json) {
    return Versiculo(
      title: json['title'] ?? '',
      number: json['number'] ?? '',
      content: json['content'] ?? '',
    );
  }
}
