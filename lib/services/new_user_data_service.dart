import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/user_data.dart';
import '../models/new_publication.dart';
import 'api_client.dart';

class UserDataService {
  static UserDataService? _instance;
  static UserDataService get instance {
    _instance ??= UserDataService._();
    return _instance!;
  }

  UserDataService._();

  static const String _userDataFileName = 'brukerdata.json';
  static const String _bookmarksFileName = 'bookmarks.json';
  static const String _publicationMappingsFileName =
      'publication_mappings.json';
  static const String _publicationMappingsApiUrl =
      'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublicationMappings';

  // Cache for publication mappings (MemberGroup -> PublicationName)
  Map<String, String>? _publicationMappingsCache;

  // Get the path to the user data file
  Future<String> _getUserDataPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_userDataFileName';
  }

  // Get the path to the bookmarks file
  Future<String> _getBookmarksPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_bookmarksFileName';
  }

  // Get the path to the publication mappings cache file
  Future<String> _getPublicationMappingsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_publicationMappingsFileName';
  }

  // Fetch publication mappings from API and cache locally
  Future<Map<String, String>> fetchAndCachePublicationMappings() async {
    try {
      print('🌐 Fetching publication mappings from API...');
      final response = await ApiClient.instance.get(_publicationMappingsApiUrl);
      final statusCode = response.statusCode;

      if (statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final List<dynamic> mappings = jsonDecode(responseBody);
        final Map<String, String> mappingsMap = {};

        for (final mapping in mappings) {
          final memberGroup = mapping['MemberGroup']?.toString();
          final publicationName = mapping['PublicationName']?.toString();

          if (memberGroup != null && publicationName != null) {
            mappingsMap[memberGroup] = publicationName;
          }
        }

        print('✅ Fetched ${mappingsMap.length} publication mappings from API');

        // Cache the mappings locally
        await _savePublicationMappings(mappingsMap);
        _publicationMappingsCache = mappingsMap;

        return mappingsMap;
      } else {
        print('❌ Failed to fetch publication mappings: $statusCode');
        // Try to load from cache
        return await _loadPublicationMappings();
      }
    } catch (e) {
      print('❌ Error fetching publication mappings: $e');
      // Try to load from cache on error
      return await _loadPublicationMappings();
    }
  }

  // Save publication mappings to local cache file
  Future<void> _savePublicationMappings(Map<String, String> mappings) async {
    try {
      final path = await _getPublicationMappingsPath();
      final file = File(path);
      final jsonString = jsonEncode(mappings);
      await file.writeAsString(jsonString);
      print('💾 Publication mappings saved to: $path');
    } catch (e) {
      print('❌ Error saving publication mappings: $e');
    }
  }

  // Load publication mappings from local cache file
  Future<Map<String, String>> _loadPublicationMappings() async {
    try {
      final path = await _getPublicationMappingsPath();
      final file = File(path);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);
        final mappings =
            jsonData.map((key, value) => MapEntry(key, value.toString()));
        print('📂 Loaded ${mappings.length} publication mappings from cache');
        _publicationMappingsCache = mappings;
        return mappings;
      }
    } catch (e) {
      print('❌ Error loading publication mappings from cache: $e');
    }

    return {};
  }

  // Get publication mappings (from cache or fetch if needed)
  Future<Map<String, String>> getPublicationMappings() async {
    if (_publicationMappingsCache != null &&
        _publicationMappingsCache!.isNotEmpty) {
      return _publicationMappingsCache!;
    }

    // Try to load from local cache first
    final cachedMappings = await _loadPublicationMappings();
    if (cachedMappings.isNotEmpty) {
      return cachedMappings;
    }

    // If no cache, fetch from API
    return await fetchAndCachePublicationMappings();
  }

  // Save user data to brukerdata.json
  Future<void> saveUserData(UserData userData) async {
    try {
      final path = await _getUserDataPath();
      final file = File(path);

      final jsonString = jsonEncode(userData.toJson());
      await file.writeAsString(jsonString);

      print('📱 User data saved to: $path');

      // Also sync bookmarks to the separate file (for preservation across logout/login)
      if (userData.bookmarks.isNotEmpty) {
        await _syncBookmarksFile(userData.bookmarks);
      }
    } catch (e) {
      print('❌ Error saving user data: $e');
      throw Exception('Failed to save user data: $e');
    }
  }

  // Sync bookmarks to the separate preservation file
  Future<void> _syncBookmarksFile(List<BookmarkedSubchapter> bookmarks) async {
    try {
      final path = await _getBookmarksPath();
      final file = File(path);
      final bookmarksJson = bookmarks.map((b) => b.toJson()).toList();
      await file.writeAsString(jsonEncode(bookmarksJson));
      print('📚 Synced ${bookmarks.length} bookmarks to preservation file');
    } catch (e) {
      print('❌ Error syncing bookmarks file: $e');
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
    List<Map<String, dynamic>>? extensionProductsData,
  }) async {
    try {
      // Fetch publication mappings from API (or load from cache)
      final publicationMappings = await fetchAndCachePublicationMappings();
      print(
          '📋 Got ${publicationMappings.length} publication mappings for subscription names');

      // Convert extension products to subscriptions using actual data from token
      final subscriptions = <Subscription>[];

      for (final productId in extensionProducts) {
        // Find the matching product data with dates
        Map<String, dynamic>? productData;
        if (extensionProductsData != null) {
          productData = extensionProductsData.firstWhere(
            (data) => data['Id']?.toString() == productId,
            orElse: () => <String, dynamic>{},
          );
        }

        DateTime? validFrom;
        DateTime? validTo;

        if (productData != null && productData.isNotEmpty) {
          // Parse ValidFrom date from token data
          if (productData['ValidFrom'] != null) {
            try {
              validFrom = DateTime.parse(productData['ValidFrom'].toString());
              print('📅 Parsed ValidFrom for $productId: $validFrom');
            } catch (e) {
              print('❌ Error parsing ValidFrom: $e');
            }
          }

          // Parse ValidTo date from token data
          if (productData['ValidTo'] != null) {
            try {
              validTo = DateTime.parse(productData['ValidTo'].toString());
              print('📅 Parsed ValidTo for $productId: $validTo');
            } catch (e) {
              print('❌ Error parsing ValidTo: $e');
            }
          }
        }

        // Get subscription name from publication mappings (MemberGroup -> PublicationName)
        final subscriptionName =
            _getSubscriptionName(productId, publicationMappings);

        subscriptions.add(
          Subscription(
            id: productId,
            name: subscriptionName,
            validFrom: validFrom,
            expiryDate: validTo,
          ),
        );
      }

      // Filter publications that the user has access to
      final activeSubscriptionIds =
          subscriptions.where((s) => s.isActive).map((s) => s.id).toList();
      final availablePublications = publications
          .where((pub) => pub.hasAccess(activeSubscriptionIds))
          .toList();

      // Load preserved bookmarks from separate file
      final preservedBookmarks = await _loadPreservedBookmarks();
      print('📚 Loaded ${preservedBookmarks.length} preserved bookmarks');

      final userData = UserData(
        email: email,
        subscriptions: subscriptions,
        availablePublications: availablePublications,
        bookmarks: preservedBookmarks,
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
        bookmarks: currentUserData.bookmarks, // Preserve existing bookmarks
        lastUpdated: DateTime.now(),
      );

      await saveUserData(updatedUserData);
      return updatedUserData;
    } catch (e) {
      print('❌ Error updating user data: $e');
      throw Exception('Failed to update user data: $e');
    }
  }

  // Delete user data (for logout) - preserves bookmarks
  Future<void> deleteUserData() async {
    try {
      // First, preserve bookmarks to separate file before deleting user data
      await _preserveBookmarks();

      final path = await _getUserDataPath();
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
        print('📱 User data deleted (bookmarks preserved)');
      }
    } catch (e) {
      print('❌ Error deleting user data: $e');
    }
  }

  // Save bookmarks to a separate file (preserved across logout/login)
  Future<void> _preserveBookmarks() async {
    try {
      final userData = await loadUserData();
      if (userData == null || userData.bookmarks.isEmpty) {
        print('📚 No bookmarks to preserve');
        return;
      }

      final path = await _getBookmarksPath();
      final file = File(path);
      final bookmarksJson = userData.bookmarks.map((b) => b.toJson()).toList();
      await file.writeAsString(jsonEncode(bookmarksJson));
      print('📚 Preserved ${userData.bookmarks.length} bookmarks to: $path');
    } catch (e) {
      print('❌ Error preserving bookmarks: $e');
    }
  }

  // Load preserved bookmarks from separate file
  Future<List<BookmarkedSubchapter>> _loadPreservedBookmarks() async {
    try {
      final path = await _getBookmarksPath();
      final file = File(path);

      if (!await file.exists()) {
        print('📚 No preserved bookmarks file found');
        return [];
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final bookmarks =
          jsonList.map((json) => BookmarkedSubchapter.fromJson(json)).toList();
      print('📚 Loaded ${bookmarks.length} preserved bookmarks from: $path');
      return bookmarks;
    } catch (e) {
      print('❌ Error loading preserved bookmarks: $e');
      return [];
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

  // Helper method to get user-friendly subscription names from publication mappings
  // The productId (from extension_Products) is matched against MemberGroup in the API response
  String _getSubscriptionName(
      String productId, Map<String, String> publicationMappings) {
    // First try to get the name from fetched publication mappings
    // The productId matches the MemberGroup field in the API response
    if (publicationMappings.containsKey(productId)) {
      final name = publicationMappings[productId]!;
      print('✅ Found subscription name for $productId: $name');
      return name;
    }

    // Fallback to hardcoded names for known product IDs (in case API doesn't have them)
    // const fallbackProductNames = {
    //   'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb': 'Enbrukerpakke',
    //   'a2dd0c91-04c8-47df-be2b-08dd055ab2cc': 'Enbrukerpakke (Gratis)',
    //   'd65933bc-07b6-45ea-4367-08dcfd7f421b': 'Premium Pakke',
    //   'ffc60e4a-3eec-4796-c881-08de27364902': 'VVS Kompetansepakke',
    //   'a11c59fb-62cd-4934-da10-08dcb14cb31c': 'Teknisk Pakke',
    // };

    // if (fallbackProductNames.containsKey(productId)) {
    //   print('⚠️ Using fallback name for $productId');
    //   return fallbackProductNames[productId]!;
    // }

    // Last resort: show truncated ID
    print('⚠️ No name found for product $productId');
    return productId;
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

  /// Check subscription status for a publication
  /// Returns a record with:
  /// - hasAccess: true if user has any subscription that grants access
  /// - isExpired: true if ALL subscriptions that grant access are expired
  /// - expiredSubscriptionNames: list of expired subscription names that granted access
  Future<
      ({
        bool hasAccess,
        bool isExpired,
        List<String> expiredSubscriptionNames
      })> checkPublicationSubscriptionStatus(String publicationId) async {
    final userData = await loadUserData();
    if (userData == null) {
      return (
        hasAccess: false,
        isExpired: false,
        expiredSubscriptionNames: <String>[]
      );
    }

    // Find the publication in availablePublications
    final publication = userData.availablePublications.firstWhere(
      (pub) => pub.id == publicationId,
      orElse: () => Publication(
        id: '',
        name: '',
        createDate: DateTime.now(),
        updateDate: DateTime.now(),
      ),
    );

    if (publication.id.isEmpty) {
      print('⚠️ Publication $publicationId not found in availablePublications');
      return (
        hasAccess: false,
        isExpired: false,
        expiredSubscriptionNames: <String>[]
      );
    }

    // If no restrictions, everyone has access
    if (publication.restrictPublicAccessIds.isEmpty) {
      return (
        hasAccess: true,
        isExpired: false,
        expiredSubscriptionNames: <String>[]
      );
    }

    // Find matching subscriptions
    final matchingSubscriptions = userData.subscriptions
        .where(
          (sub) => publication.restrictPublicAccessIds.contains(sub.id),
        )
        .toList();

    if (matchingSubscriptions.isEmpty) {
      print('⚠️ No matching subscriptions for publication $publicationId');
      return (
        hasAccess: false,
        isExpired: false,
        expiredSubscriptionNames: <String>[]
      );
    }

    // Check if any subscription is still active
    final now = DateTime.now();
    final activeSubscriptions =
        matchingSubscriptions.where((sub) => sub.isActive).toList();
    final expiredSubscriptions =
        matchingSubscriptions.where((sub) => !sub.isActive).toList();

    // Get names of expired subscriptions
    final expiredNames = expiredSubscriptions.map((sub) => sub.name).toList();

    if (activeSubscriptions.isNotEmpty) {
      // At least one subscription is still active
      return (
        hasAccess: true,
        isExpired: false,
        expiredSubscriptionNames: <String>[]
      );
    } else {
      // All matching subscriptions are expired
      print(
          '⚠️ All subscriptions for publication $publicationId are expired: $expiredNames');
      return (
        hasAccess: true,
        isExpired: true,
        expiredSubscriptionNames: expiredNames
      );
    }
  }
}
