class SubChapter {
  final String id;
  final String title;
  final String? webUrl;
  final String? number;
  final String? bookId;

  SubChapter(
      {required this.id,
      required this.title,
      this.webUrl,
      this.number,
      this.bookId});

  factory SubChapter.fromJson(Map<String, dynamic> json) {
    return SubChapter(
      id: json['ID'] ?? '',
      title: json['Title'] ?? '',
      webUrl: json['webUrl']?.toString(),
      number: json['Number']?.toString(),
      bookId: json['bookId'] ?? json['BookId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'ID': id,
        'Title': title,
        'webUrl': webUrl,
        'Number': number,
        'bookId': bookId,
      };
}
