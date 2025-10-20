class Publication {
  final String id;
  final String name;
  final String? title;
  final String? imageUrl;
  final String? url;
  final DateTime createDate;
  final DateTime updateDate;
  final DateTime? newVersionDate; // New version date from API
  final List<String> restrictPublicAccessIds;
  final int? dataSizeInBytes;
  final String? dataSize;
  final int? chapterCount;
  final int? subchapterCount;

  Publication({
    required this.id,
    required this.name,
    this.title,
    this.imageUrl,
    this.url,
    required this.createDate,
    required this.updateDate,
    this.newVersionDate,
    this.restrictPublicAccessIds = const [],
    this.dataSizeInBytes,
    this.dataSize,
    this.chapterCount,
    this.subchapterCount,
  });

  factory Publication.fromJson(Map<String, dynamic> json) {
    return Publication(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
      title: json['Title'],
      imageUrl: json['ImageUrl'],
      url: json['Url'],
      createDate: DateTime.parse(json['CreateDate']),
      updateDate: DateTime.parse(json['UpdateDate']),
      newVersionDate: json['NewVersionDate'] != null
          ? DateTime.parse(json['NewVersionDate'])
          : null,
      restrictPublicAccessIds:
          List<String>.from(json['RestrictPublicAccessIds'] ?? []),
      dataSizeInBytes: json['DataSizeInBytes'],
      dataSize: json['DataSize'],
      chapterCount: json['ChapterCount'],
      subchapterCount: json['SubchapterCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Title': title,
      'ImageUrl': imageUrl,
      'Url': url,
      'CreateDate': createDate.toIso8601String(),
      'UpdateDate': updateDate.toIso8601String(),
      'NewVersionDate': newVersionDate?.toIso8601String(),
      'RestrictPublicAccessIds': restrictPublicAccessIds,
      'DataSizeInBytes': dataSizeInBytes,
      'DataSize': dataSize,
      'ChapterCount': chapterCount,
      'SubchapterCount': subchapterCount,
    };
  }

  // Check if user has access to this publication
  bool hasAccess(List<String> userSubscriptions) {
    // If no access restrictions, everyone has access
    if (restrictPublicAccessIds.isEmpty) {
      return true;
    }

    // Check if user has any of the required subscriptions
    return userSubscriptions
        .any((subscription) => restrictPublicAccessIds.contains(subscription));
  }
}

class Chapter {
  final String title;
  final String? subtitle;
  final String? number;
  final String? abstract;
  final List<Subchapter> subchapters;

  Chapter({
    required this.title,
    this.subtitle,
    this.number,
    this.abstract,
    this.subchapters = const [],
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      title: json['Title'] ?? '',
      subtitle: json['Subtitle'],
      number: json['Number'],
      abstract: json['Abstract'],
      subchapters: (json['Subchapters'] as List<dynamic>?)
              ?.map((subchapter) => Subchapter.fromJson(subchapter))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Title': title,
      'Subtitle': subtitle,
      'Number': number,
      'Abstract': abstract,
      'Subchapters': subchapters.map((s) => s.toJson()).toList(),
    };
  }
}

class Subchapter {
  final String title;
  final String text;
  final String? number;

  Subchapter({
    required this.title,
    required this.text,
    this.number,
  });

  factory Subchapter.fromJson(Map<String, dynamic> json) {
    return Subchapter(
      title: json['Title'] ?? '',
      text: json['Text'] ?? '',
      number: json['Number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Title': title,
      'Text': text,
      'Number': number,
    };
  }
}
