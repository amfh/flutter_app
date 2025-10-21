import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/publication.dart';
import '../main.dart';
import 'publication_service.dart';
import 'local_storage_service.dart';
import 'publication_access_service.dart';
import 'api_client.dart';

class UpdateCheckService {
  static final UpdateCheckService _instance = UpdateCheckService._internal();
  static UpdateCheckService get instance => _instance;
  UpdateCheckService._internal();

  Timer? _updateTimer;
  final PublicationService _publicationService = PublicationService();

  // Check for updates every 30 minutes
  static const Duration _checkInterval = Duration(minutes: 30);

  // Cache key for storing last update check time
  static const String _lastCheckCacheKey = 'last_update_check.json';

  // Start background update checking - DISABLED
  void startBackgroundChecking(BuildContext? context) {
    print('📅 Background update checking is disabled');
    // Background checking disabled for development
    return;
  }

  // Stop background update checking
  void stopBackgroundChecking() {
    _updateTimer?.cancel();
    _updateTimer = null;
    print('🛑 Background update checking stopped');
  }

  // Perform update check - DISABLED
  Future<void> _performUpdateCheck(BuildContext? context) async {
    // Background checking disabled
    return;
  }

  // Fetch publications from API
  Future<List<Publication>> _fetchPublicationsFromApi() async {
    try {
      final urls = [
        'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublications',
        'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublications',
        // 'https://localhost:44342/umbraco/api/AppApi/GetPublications',
        // 'https://10.0.2.2:44342/umbraco/api/AppApi/GetPublications',
        // 'https://127.0.0.1:44342/umbraco/api/AppApi/GetPublications',
        // 'http://localhost:44342/umbraco/api/AppApi/GetPublications',
        // 'http://10.0.2.2:44342/umbraco/api/AppApi/GetPublications',
        // 'http://127.0.0.1:44342/umbraco/api/AppApi/GetPublications',
      ];

      for (String url in urls) {
        try {
          print('🌐 Trying API URL: $url');

          final response = await ApiClient.instance.get(url);

          if (response.statusCode == 200) {
            final responseBody = await response.transform(utf8.decoder).join();
            final List<dynamic> data = json.decode(responseBody);

            // Filter publications based on user access
            final filteredPublications =
                PublicationAccessService.filterPublicationsByAccess(
                        data.cast<Map<String, dynamic>>())
                    .map((json) => Publication.fromJson(json))
                    .toList();

            print(
                '✅ Successfully fetched ${filteredPublications.length} accessible publications from API');
            return filteredPublications;
          }
        } catch (e) {
          print('❌ Error fetching from $url: $e');
          continue;
        }
      }

      print('❌ Failed to fetch publications from all API endpoints');
      return [];
    } catch (e) {
      print('❌ Error in _fetchPublicationsFromApi: $e');
      return [];
    }
  }

  // Get local publication update dates from downloaded content files
  Future<Map<String, DateTime>> _getLocalPublicationUpdateDates() async {
    try {
      final Map<String, DateTime> updateDates = {};

      // Get all downloaded publications by checking for fullcontent files
      final List<String> downloadedPublications =
          await _getDownloadedPublicationIds();

      for (final publicationId in downloadedPublications) {
        try {
          final contentData = await LocalStorageService.readJson(
              'fullcontent_$publicationId.json');
          if (contentData != null && contentData['UpdateDate'] != null) {
            final updateDate =
                DateTime.parse(contentData['UpdateDate'].toString());
            updateDates[publicationId] = updateDate;
            print('📅 Found UpdateDate for $publicationId: $updateDate');
          } else {
            print(
                '⚠️ No UpdateDate found in downloaded content for $publicationId');
          }
        } catch (e) {
          print(
              '❌ Error reading UpdateDate from content for $publicationId: $e');
        }
      }

      print(
          '📅 Loaded ${updateDates.length} UpdateDates from downloaded content');
      return updateDates;
    } catch (e) {
      print('❌ Error loading local update dates: $e');
      return {};
    }
  }

  // Get list of publication IDs that have been downloaded
  Future<List<String>> _getDownloadedPublicationIds() async {
    try {
      final List<String> publicationIds = [];

      // This is a simplified approach - in a real implementation you might
      // want to scan the storage directory for fullcontent_*.json files
      // For now, we'll try to get this from the cached publications list
      final cachedPublications =
          await LocalStorageService.readJson('cached_publications.json');
      if (cachedPublications != null && cachedPublications is List) {
        for (final pub in cachedPublications) {
          if (pub is Map<String, dynamic> && pub['Id'] != null) {
            final publicationId = pub['Id'].toString();
            // Check if this publication is actually downloaded
            if (await _hasLocalContent(publicationId)) {
              publicationIds.add(publicationId);
            }
          }
        }
      }

      print('� Found ${publicationIds.length} downloaded publications');
      return publicationIds;
    } catch (e) {
      print('❌ Error getting downloaded publication IDs: $e');
      return [];
    }
  }

  // Check for updates by comparing API and local update dates
  Future<List<Publication>> _checkForUpdates(List<Publication> apiPublications,
      Map<String, DateTime> localUpdateDates) async {
    final List<Publication> updatesAvailable = [];

    for (final pub in apiPublications) {
      if (pub.updateDate == null) {
        print('⚠️ No UpdateDate in API for ${pub.title}, skipping');
        continue;
      }

      // Check if we have this publication downloaded locally
      final hasLocalContent = await _hasLocalContent(pub.id);
      if (!hasLocalContent) {
        print('📂 ${pub.title} not downloaded locally, skipping');
        continue; // Skip if not downloaded locally
      }

      final localUpdateDate = localUpdateDates[pub.id];

      if (localUpdateDate == null) {
        // No local update date found in downloaded content
        print(
            '📝 No UpdateDate found in downloaded content for ${pub.title}, marking for update');
        updatesAvailable.add(pub);
      } else if (pub.updateDate!.isAfter(localUpdateDate)) {
        // API version is newer than downloaded version
        print('🆕 Update available for ${pub.title}:');
        print('   📡 API version: ${pub.updateDate}');
        print('   💾 Downloaded version: $localUpdateDate');
        print(
            '   ⏰ Difference: ${pub.updateDate!.difference(localUpdateDate).inDays} days');
        updatesAvailable.add(pub);
      } else {
        print(
            '✅ ${pub.title} is up to date (API: ${pub.updateDate}, Local: $localUpdateDate)');
      }
    }

    return updatesAvailable;
  }

  // Check if publication has local content
  Future<bool> _hasLocalContent(String publicationId) async {
    try {
      final data =
          await LocalStorageService.readJson('fullcontent_$publicationId.json');
      return data != null;
    } catch (e) {
      return false;
    }
  }

  // Show update notification to user
  void _showUpdateNotification(
      BuildContext context, List<Publication> updatesAvailable) {
    if (!context.mounted) return;

    final publicationNames = updatesAvailable.map((p) => p.title).join(', ');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Nye oppdateringer tilgjengelig!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              updatesAvailable.length == 1
                  ? 'Oppdatering tilgjengelig for: $publicationNames'
                  : 'Oppdateringer tilgjengelige for ${updatesAvailable.length} publikasjoner',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gå til Min side for å laste ned nye versjoner',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Min side',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to My Page screen
            Navigator.of(context).pushNamed('/my_page');
          },
        ),
      ),
    );
  }

  // Update last check time
  Future<void> _updateLastCheckTime() async {
    try {
      await LocalStorageService.writeJson(_lastCheckCacheKey, {
        'lastCheck': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Error updating last check time: $e');
    }
  }

  // Note: UpdateDate is now read directly from downloaded content files
  // No separate caching needed since it's stored in fullcontent_*.json

  // Manual update check (can be called from UI)
  Future<List<Publication>> checkForUpdatesManually() async {
    try {
      final isLoggedIn = await UserSession.instance.isLoggedIn();
      if (!isLoggedIn) {
        throw Exception('User not logged in');
      }

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection');
      }

      final apiPublications = await _fetchPublicationsFromApi();
      final localUpdateDates = await _getLocalPublicationUpdateDates();

      return await _checkForUpdates(apiPublications, localUpdateDates);
    } catch (e) {
      print('❌ Error in manual update check: $e');
      rethrow;
    }
  }

  // Get last update check time
  Future<DateTime?> getLastCheckTime() async {
    try {
      final data = await LocalStorageService.readJson(_lastCheckCacheKey);
      if (data != null && data['lastCheck'] != null) {
        return DateTime.parse(data['lastCheck']);
      }
    } catch (e) {
      print('❌ Error getting last check time: $e');
    }
    return null;
  }

  // Dispose resources
  void dispose() {
    stopBackgroundChecking();
    _publicationService.dispose();
  }
}
