import 'new_publication.dart';

class UserData {
  final String email;
  final List<Subscription> subscriptions;
  final List<Publication> availablePublications;
  final List<BookmarkedSubchapter> bookmarks;
  final DateTime lastUpdated;

  UserData({
    required this.email,
    required this.subscriptions,
    required this.availablePublications,
    this.bookmarks = const [],
    required this.lastUpdated,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      email: json['email'] ?? '',
      subscriptions: (json['subscriptions'] as List<dynamic>?)
              ?.map((sub) => Subscription.fromJson(sub))
              .toList() ??
          [],
      availablePublications: (json['availablePublications'] as List<dynamic>?)
              ?.map((pub) => Publication.fromJson(pub))
              .toList() ??
          [],
      bookmarks: (json['bookmarks'] as List<dynamic>?)
              ?.map((b) => BookmarkedSubchapter.fromJson(b))
              .toList() ??
          [],
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
      'availablePublications':
          availablePublications.map((p) => p.toJson()).toList(),
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // Get all active subscription IDs
  List<String> getActiveSubscriptionIds() {
    // TODO: TESTING - Remove this line and use DateTime.now() in production
    //final now = DateTime(2026, 10, 21); // Test date: 21.10.2026
    final now = DateTime.now();
    return subscriptions
        .where((sub) => sub.expiryDate == null || sub.expiryDate!.isAfter(now))
        .map((sub) => sub.id)
        .toList();
  }

  // Get available publications with active subscriptions
  List<Publication> getAccessiblePublications() {
    final activeSubscriptionIds = getActiveSubscriptionIds();
    return availablePublications
        .where((pub) => pub.hasAccess(activeSubscriptionIds))
        .toList();
  }
}

class Subscription {
  final String id;
  final String name;
  final DateTime? validFrom;
  final DateTime? expiryDate;

  Subscription({
    required this.id,
    required this.name,
    this.validFrom,
    this.expiryDate,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      validFrom:
          json['validFrom'] != null ? DateTime.parse(json['validFrom']) : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'validFrom': validFrom?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }

  bool get isActive {
    // TODO: TESTING - Remove this line and use DateTime.now() in production
    //final now = DateTime(2026, 10, 21); // Test date: 21.10.2026
    final now = DateTime.now();
    // Check if subscription has started (validFrom)
    if (validFrom != null && validFrom!.isAfter(now)) {
      return false; // Subscription hasn't started yet
    }
    // Check if subscription has expired (expiryDate/validTo)
    if (expiryDate == null) return true;
    return expiryDate!.isAfter(now);
  }
}

class BookmarkedSubchapter {
  final String publicationId;
  final String publicationName;
  final String chapterTitle;
  final String subchapterTitle;
  final String? subchapterNumber;
  final DateTime bookmarkedAt;

  BookmarkedSubchapter({
    required this.publicationId,
    required this.publicationName,
    required this.chapterTitle,
    required this.subchapterTitle,
    this.subchapterNumber,
    required this.bookmarkedAt,
  });

  factory BookmarkedSubchapter.fromJson(Map<String, dynamic> json) {
    return BookmarkedSubchapter(
      publicationId: json['publicationId'] ?? '',
      publicationName: json['publicationName'] ?? '',
      chapterTitle: json['chapterTitle'] ?? '',
      subchapterTitle: json['subchapterTitle'] ?? '',
      subchapterNumber: json['subchapterNumber'],
      bookmarkedAt: DateTime.parse(json['bookmarkedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'publicationId': publicationId,
      'publicationName': publicationName,
      'chapterTitle': chapterTitle,
      'subchapterTitle': subchapterTitle,
      'subchapterNumber': subchapterNumber,
      'bookmarkedAt': bookmarkedAt.toIso8601String(),
    };
  }

  // Unique identifier for the bookmark
  String get id => '${publicationId}_${chapterTitle}_$subchapterTitle';
}
