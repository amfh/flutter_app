class Publication {
  final String id;
  final String title;
  final String ingress;
  final String url;
  final String imageUrl;
  final List<String> restrictPublicAccessIds;
  final DateTime? createDate;
  final DateTime? updateDate;
  final int? dataSizeInBytes;
  final String? dataSize;
  final int? chapterCount;
  final int? subchapterCount;

  Publication({
    required this.id,
    required this.title,
    required this.ingress,
    required this.url,
    required this.imageUrl,
    required this.restrictPublicAccessIds,
    this.createDate,
    this.updateDate,
    this.dataSizeInBytes,
    this.dataSize,
    this.chapterCount,
    this.subchapterCount,
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

    // Parse dates safely
    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      try {
        return DateTime.parse(dateValue.toString());
      } catch (e) {
        print('Error parsing date: $dateValue');
        return null;
      }
    }

    return Publication(
      id: json['Id'] ?? '',
      title: json['Title'] ?? json['Name'] ?? '',
      ingress: json['Ingress'] ?? '',
      url: json['Url'] ?? '',
      imageUrl: json['ImageUrl'] ?? '',
      restrictPublicAccessIds: restrictIds,
      createDate: parseDate(json['CreateDate']),
      updateDate: parseDate(json['UpdateDate']),
      dataSizeInBytes: json['DataSizeInBytes'] as int?,
      dataSize: json['DataSize'] as String?,
      chapterCount: json['ChapterCount'] as int?,
      subchapterCount: json['SubchapterCount'] as int?,
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
      'CreateDate': createDate?.toIso8601String(),
      'UpdateDate': updateDate?.toIso8601String(),
      'DataSizeInBytes': dataSizeInBytes,
      'DataSize': dataSize,
      'ChapterCount': chapterCount,
      'SubchapterCount': subchapterCount,
    };
  }
}
