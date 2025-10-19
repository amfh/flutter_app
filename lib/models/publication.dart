class Publication {
  final String id;
  final String title;
  final String ingress;
  final String url;
  final String imageUrl;
  final List<String> restrictPublicAccessIds;

  Publication({
    required this.id,
    required this.title,
    required this.ingress,
    required this.url,
    required this.imageUrl,
    required this.restrictPublicAccessIds,
  });

  factory Publication.fromJson(Map<String, dynamic> json) {
    // Parse RestrictPublicAccessIds as List<String>
    List<String> restrictIds = [];
    if (json['RestrictPublicAccessIds'] != null) {
      if (json['RestrictPublicAccessIds'] is List) {
        restrictIds = (json['RestrictPublicAccessIds'] as List)
            .map((id) => id.toString())
            .toList();
      }
    }

    return Publication(
      id: json['Id'] ?? '',
      title: json['Title'] ?? '',
      ingress: json['Ingress'] ?? '',
      url: json['Url'] ?? '',
      imageUrl: json['ImageUrl'] ?? '',
      restrictPublicAccessIds: restrictIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Title': title,
      'Ingress': ingress,
      'Url': url,
      'ImageUrl': imageUrl,
      'RestrictPublicAccessIds': restrictPublicAccessIds,
    };
  }
}
