class SubChapter {
  final String id;
  final String title;
  final String? webUrl;
  final String? number;
  final String? bookId;
  final String? text;

  SubChapter(
      {required this.id,
      required this.title,
      this.webUrl,
      this.number,
      this.bookId,
      this.text});

  factory SubChapter.fromJson(Map<String, dynamic> json) {
    // Generate ID from title if not provided (since API doesn't provide IDs)
    String title = json['Title'] ?? json['title'] ?? '';
    String id = json['ID'] ?? json['Id'] ?? json['id'] ?? '';

    if (id.isEmpty && title.isNotEmpty) {
      id = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    }

    return SubChapter(
      id: id,
      title: title,
      webUrl: json['webUrl']?.toString(),
      number: json['Number']?.toString() ?? json['number']?.toString(),
      bookId: json['bookId'] ?? json['BookId'] ?? '',
      text: json['Text']?.toString() ?? json['text']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'ID': id,
        'Title': title,
        'webUrl': webUrl,
        'Number': number,
        'bookId': bookId,
        'Text': text,
      };
}
