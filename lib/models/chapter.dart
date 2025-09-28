class Chapter {
  final String id;
  final String title;
  final String url;

  Chapter({
    required this.id,
    required this.title,
    required this.url,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['ID'] ?? '',
      title: json['Title'] ?? '',
      url: json['Url'] ?? '',
    );
  }
}
