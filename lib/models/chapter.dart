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
    String title =
        json['Title'] ?? json['title'] ?? json['Name'] ?? json['name'] ?? '';
    String id = json['ID'] ?? json['Id'] ?? json['id'] ?? '';

    // If no ID is provided, generate one from the title
    if (id.isEmpty && title.isNotEmpty) {
      id = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    }

    return Chapter(
      id: id,
      title: title,
      url: json['Url'] ?? json['url'] ?? json['URL'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': id,
      'Title': title,
      'Url': url,
    };
  }
}
