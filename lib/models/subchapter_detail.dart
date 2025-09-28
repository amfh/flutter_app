class SubChapterDetail {
  final String id;
  final String title;
  final String? number;
  final String? text;

  SubChapterDetail(
      {required this.id, required this.title, this.number, this.text});

  factory SubChapterDetail.fromJson(Map<String, dynamic> json) {
    return SubChapterDetail(
      id: json['ID'] ?? '',
      title: json['Title'] ?? '',
      number: json['Number']?.toString(),
      text: json['Text'] ?? '',
    );
  }
}
