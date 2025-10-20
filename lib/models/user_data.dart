import 'new_publication.dart';

class UserData {
  final String email;
  final List<Subscription> subscriptions;
  final List<Publication> availablePublications;
  final DateTime lastUpdated;

  UserData({
    required this.email,
    required this.subscriptions,
    required this.availablePublications,
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
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
      'availablePublications':
          availablePublications.map((p) => p.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // Get all active subscription IDs
  List<String> getActiveSubscriptionIds() {
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
  final DateTime? expiryDate;

  Subscription({
    required this.id,
    required this.name,
    this.expiryDate,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }

  bool get isActive {
    if (expiryDate == null) return true;
    return expiryDate!.isAfter(DateTime.now());
  }
}
