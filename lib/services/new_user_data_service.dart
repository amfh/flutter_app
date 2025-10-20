import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/user_data.dart';
import '../models/new_publication.dart';

class UserDataService {
  static UserDataService? _instance;
  static UserDataService get instance {
    _instance ??= UserDataService._();
    return _instance!;
  }

  UserDataService._();

  static const String _userDataFileName = 'brukerdata.json';

  // Get the path to the user data file
  Future<String> _getUserDataPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_userDataFileName';
  }

  // Save user data to brukerdata.json
  Future<void> saveUserData(UserData userData) async {
    try {
      final path = await _getUserDataPath();
      final file = File(path);

      final jsonString = jsonEncode(userData.toJson());
      await file.writeAsString(jsonString);

      print('📱 User data saved to: $path');
    } catch (e) {
      print('❌ Error saving user data: $e');
      throw Exception('Failed to save user data: $e');
    }
  }

  // Load user data from brukerdata.json
  Future<UserData?> loadUserData() async {
    try {
      final path = await _getUserDataPath();
      final file = File(path);

      if (!await file.exists()) {
        print('📱 No user data file found');
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);

      final userData = UserData.fromJson(jsonData);
      print('📱 User data loaded from: $path');

      return userData;
    } catch (e) {
      print('❌ Error loading user data: $e');
      return null;
    }
  }

  // Create user data after successful login
  Future<UserData> createUserData({
    required String email,
    required List<String> extensionProducts,
    required List<Publication> publications,
  }) async {
    try {
      // Convert extension products to subscriptions with sample expiry dates
      final subscriptions = extensionProducts.asMap().entries.map((entry) {
        final index = entry.key;
        final productId = entry.value;

        // Create sample expiry dates for demonstration
        DateTime? expiryDate;
        if (index == 0) {
          // First subscription expires in 6 months
          expiryDate = DateTime.now().add(const Duration(days: 180));
        } else if (index == 1) {
          // Second subscription expires in 2 weeks (soon to expire)
          expiryDate = DateTime.now().add(const Duration(days: 14));
        } else {
          // Additional subscriptions get 1 year
          expiryDate = DateTime.now().add(const Duration(days: 365));
        }

        return Subscription(
          id: productId,
          name: _getSubscriptionName(productId),
          expiryDate: expiryDate,
        );
      }).toList();

      // Add one expired subscription for demonstration
      subscriptions.add(
        Subscription(
          id: 'expired-demo',
          name: 'Grunnkurs VVS (Utløpt)',
          expiryDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );

      // Filter publications that the user has access to
      final activeSubscriptionIds = subscriptions.map((s) => s.id).toList();
      final availablePublications = publications
          .where((pub) => pub.hasAccess(activeSubscriptionIds))
          .toList();

      final userData = UserData(
        email: email,
        subscriptions: subscriptions,
        availablePublications: availablePublications,
        lastUpdated: DateTime.now(),
      );

      await saveUserData(userData);
      return userData;
    } catch (e) {
      print('❌ Error creating user data: $e');
      throw Exception('Failed to create user data: $e');
    }
  }

  // Update user data with new publications
  Future<UserData> updateUserData(
      UserData currentUserData, List<Publication> newPublications) async {
    try {
      // Filter publications that the user has access to
      final activeSubscriptionIds = currentUserData.getActiveSubscriptionIds();
      final availablePublications = newPublications
          .where((pub) => pub.hasAccess(activeSubscriptionIds))
          .toList();

      final updatedUserData = UserData(
        email: currentUserData.email,
        subscriptions: currentUserData.subscriptions,
        availablePublications: availablePublications,
        lastUpdated: DateTime.now(),
      );

      await saveUserData(updatedUserData);
      return updatedUserData;
    } catch (e) {
      print('❌ Error updating user data: $e');
      throw Exception('Failed to update user data: $e');
    }
  }

  // Delete user data (for logout)
  Future<void> deleteUserData() async {
    try {
      final path = await _getUserDataPath();
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
        print('📱 User data deleted');
      }
    } catch (e) {
      print('❌ Error deleting user data: $e');
    }
  }

  // Check if user data exists
  Future<bool> hasUserData() async {
    try {
      final path = await _getUserDataPath();
      final file = File(path);
      return await file.exists();
    } catch (e) {
      print('❌ Error checking user data: $e');
      return false;
    }
  }

  // Helper method to get user-friendly subscription names
  String _getSubscriptionName(String productId) {
    // Map known product IDs to friendly names
    const productNames = {
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb': 'Enbrukerpakke',
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc': 'Enbrukerpakke (Gratis)',
      'd65933bc-07b6-45ea-4367-08dcfd7f421b': 'Premium Pakke',
    };

    return productNames[productId] ?? 'Ukjent abonnement ($productId)';
  }

  // Get accessible publications for current user
  Future<List<Publication>> getAccessiblePublications() async {
    final userData = await loadUserData();
    if (userData == null) return [];

    return userData.getAccessiblePublications();
  }

  // Check if a specific publication is accessible
  Future<bool> hasAccessToPublication(String publicationId) async {
    final accessiblePublications = await getAccessiblePublications();
    return accessiblePublications.any((pub) => pub.id == publicationId);
  }
}
