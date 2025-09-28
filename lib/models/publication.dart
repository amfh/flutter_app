class Publication {
  final String id;
  final String title;
  final String ingress;
  final String url;
  final String imageUrl;

  Publication({
    required this.id,
    required this.title,
    required this.ingress,
    required this.url,
    required this.imageUrl,
  });

  factory Publication.fromJson(Map<String, dynamic> json) {
    return Publication(
      id: json['Id'] ?? '',
      title: json['Title'] ?? '',
      ingress: json['Ingress'] ?? '',
      url: json['Url'] ?? '',
      imageUrl: json['ImageUrl'] ?? '',
    );
  }
}
