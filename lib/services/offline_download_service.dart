import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/publication.dart';
import '../services/publication_service.dart';
import '../services/local_storage_service.dart';
import '../services/publication_access_service.dart';

class OfflineDownloadService {
  final PublicationService _publicationService = PublicationService();

  // HTTP client that accepts self-signed certificates for localhost
  late HttpClient _httpClient;

  OfflineDownloadService() {
    _httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Accept all certificates for localhost development
        return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
      };
  }

  void dispose() {
    _httpClient.close();
  }

  /// Download all publications that the current user has access to (content only, no images)
  Future<DownloadResult> downloadUserAccessiblePublications({
    Function(String)? onProgress,
    Function(DownloadProgress)? onProgressWithPercent,
    Function(String)? onError,
  }) async {
    final result = DownloadResult();

    try {
      // Use only the text progress for initial setup phases
      onProgress?.call('Starting download...');

      // Debug: Check user session state
      print('=== USER SESSION DEBUG ===');
      print(
          'UserSession.instance.extensionProducts: ${UserSession.instance.extensionProducts}');
      print(
          'UserSession.instance.idToken != null: ${UserSession.instance.idToken != null}');
      print(
          'UserSession.instance.userEmail: ${UserSession.instance.userEmail}');

      // Get user's extension products using the same method as PublicationAccessService
      final userAccessIds = PublicationAccessService.getUserAccessIds();
      print('PublicationAccessService.getUserAccessIds(): $userAccessIds');

      if (userAccessIds.isEmpty) {
        final errorMsg =
            'No extension products found for user. User must be logged in with valid access rights.';
        onError?.call(errorMsg);
        throw Exception(errorMsg);
      }

      onProgress?.call('Getting publications list...');

      // Fetch all publications from API
      final allPublications = await _fetchPublicationsFromApi();

      // Filter publications based on user access
      final accessiblePublications =
          _filterPublicationsByUserAccess(allPublications);

      // Now we know the total count, so start using percentage progress
      onProgress?.call(
          'Found ${accessiblePublications.length} accessible publications');
      onProgressWithPercent?.call(DownloadProgress(
        currentItem: 0,
        totalItems: accessiblePublications.length,
        currentTask:
            'Starting download of ${accessiblePublications.length} publications',
      ));
      result.totalPublications = accessiblePublications.length;

      // Download each accessible publication
      for (int i = 0; i < accessiblePublications.length; i++) {
        final publication = accessiblePublications[i];

        try {
          final progressMessage = 'Downloading: ${publication.title}';
          onProgress?.call(
              'Downloading publication ${i + 1}/${accessiblePublications.length}: ${publication.title}');
          onProgressWithPercent?.call(DownloadProgress(
            currentItem: i + 1,
            totalItems: accessiblePublications.length,
            currentTask: progressMessage,
          ));

          print(
              '🔥 About to call downloadAndCacheFullContent for ${publication.id}');

          // Download content only (without images)
          await _publicationService.downloadAndCacheContentOnly(publication.id);
          print(
              '🔥 Completed downloadAndCacheContentOnly for ${publication.id}');

          // Download publication cover image only (not content images)
          if (publication.imageUrl.isNotEmpty) {
            await _publicationService.downloadAndCacheImage(
                publication.imageUrl, publication.id);
          }

          result.successfulDownloads++;
          onProgress?.call('✓ Downloaded: ${publication.title}');
        } catch (e, stackTrace) {
          result.failedDownloads++;
          final errorMsg = 'Failed to download ${publication.title}: $e';
          print('🚨 OFFLINE DOWNLOAD EXCEPTION: $errorMsg');
          print('🚨 STACK TRACE: $stackTrace');
          onError?.call(errorMsg);
          result.errors.add(errorMsg);
        }
      }

      // Save the list of accessible publications for offline use
      await _saveAccessiblePublicationsList(accessiblePublications);

      final completeMessage =
          'Download complete! ${result.successfulDownloads} successful, ${result.failedDownloads} failed';
      onProgress?.call(completeMessage);
      onProgressWithPercent?.call(DownloadProgress(
        currentItem: accessiblePublications.length,
        totalItems: accessiblePublications.length,
        currentTask: completeMessage,
      ));
    } catch (e) {
      result.errors.add('Download failed: $e');
      onError?.call('Download failed: $e');
    }

    return result;
  }

  /// Download images for already cached publications
  Future<DownloadResult> downloadImagesForOfflinePublications({
    Function(String)? onProgress,
    Function(DownloadProgress)? onProgressWithPercent,
    Function(String)? onError,
  }) async {
    final result = DownloadResult();

    try {
      onProgress?.call('Loading offline publications...');

      // Get offline publications that we have content for
      final offlinePublications = await getOfflinePublications();

      if (offlinePublications.isEmpty) {
        final errorMsg =
            'No offline publications found. Download content first.';
        onError?.call(errorMsg);
        throw Exception(errorMsg);
      }

      onProgress
          ?.call('Found ${offlinePublications.length} offline publications');
      onProgressWithPercent?.call(DownloadProgress(
        currentItem: 0,
        totalItems: offlinePublications.length,
        currentTask:
            'Starting image download for ${offlinePublications.length} publications',
      ));
      result.totalPublications = offlinePublications.length;

      // Download images for each publication
      for (int i = 0; i < offlinePublications.length; i++) {
        final publication = offlinePublications[i];

        try {
          final progressMessage = 'Downloading images: ${publication.title}';
          onProgress?.call(
              'Downloading images ${i + 1}/${offlinePublications.length}: ${publication.title}');
          onProgressWithPercent?.call(DownloadProgress(
            currentItem: i + 1,
            totalItems: offlinePublications.length,
            currentTask: progressMessage,
          ));

          print('🔥 About to download images for ${publication.id}');

          // Download images for this publication
          await _publicationService
              .downloadImagesForCachedPublication(publication.id);
          print('🔥 Completed image download for ${publication.id}');

          result.successfulDownloads++;
          onProgress?.call('✓ Images downloaded: ${publication.title}');
        } catch (e, stackTrace) {
          result.failedDownloads++;
          final errorMsg =
              'Failed to download images for ${publication.title}: $e';
          print('🚨 IMAGE DOWNLOAD EXCEPTION: $errorMsg');
          print('🚨 STACK TRACE: $stackTrace');
          onError?.call(errorMsg);
          result.errors.add(errorMsg);
        }
      }

      final completeMessage =
          'Image download complete! ${result.successfulDownloads} successful, ${result.failedDownloads} failed';
      onProgress?.call(completeMessage);
      onProgressWithPercent?.call(DownloadProgress(
        currentItem: offlinePublications.length,
        totalItems: offlinePublications.length,
        currentTask: completeMessage,
      ));
    } catch (e) {
      result.errors.add('Image download failed: $e');
      onError?.call('Image download failed: $e');
    }

    return result;
  }

  /// Get accessible publications for the current user (public method for UI)
  Future<List<Publication>> getAccessiblePublications() async {
    try {
      // Get user's extension products
      final userAccessIds = PublicationAccessService.getUserAccessIds();

      if (userAccessIds.isEmpty) {
        return [];
      }

      // Fetch all publications from API
      final allPublications = await _fetchPublicationsFromApi();

      // Filter publications based on user access
      final accessiblePublications =
          _filterPublicationsByUserAccess(allPublications);

      return accessiblePublications;
    } catch (e) {
      print('Error getting accessible publications: $e');
      return [];
    }
  }

  /// Fetch all publications from API
  Future<List<Publication>> _fetchPublicationsFromApi() async {
    final urls = [
      'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublications'
      // 'https://10.0.2.2:44342/umbraco/api/AppApi/GetPublications',
      // 'https://127.0.0.1:44342/umbraco/api/AppApi/GetPublications',
      // 'http://localhost:44342/umbraco/api/AppApi/GetPublications',
      // 'http://10.0.2.2:44342/umbraco/api/AppApi/GetPublications',
      // 'http://127.0.0.1:44342/umbraco/api/AppApi/GetPublications',
    ];

    for (String url in urls) {
      try {
        print('Trying publications API URL: $url');

        dynamic data;
        if (url.startsWith('https://')) {
          // Use custom HTTP client for HTTPS URLs
          final request = await _httpClient.getUrl(Uri.parse(url));
          request.headers.set('Content-Type', 'application/json');
          final httpResponse =
              await request.close().timeout(const Duration(seconds: 15));

          if (httpResponse.statusCode == 200) {
            final responseBody =
                await httpResponse.transform(utf8.decoder).join();
            data = json.decode(responseBody);
            print('Success fetching publications from: $url');
          } else {
            continue;
          }
        } else {
          // Use regular http package for HTTP URLs
          final response = await http.get(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            data = json.decode(response.body);
            print('Success fetching publications from: $url');
          } else {
            continue;
          }
        }

        if (data is List) {
          return data.map((json) => Publication.fromJson(json)).toList();
        } else {
          throw Exception('Unexpected response format');
        }
      } catch (e) {
        print('Error fetching publications from $url: $e');
        continue;
      }
    }

    throw Exception('Failed to fetch publications from all API endpoints');
  }

  /// Filter publications based on user's extension products
  List<Publication> _filterPublicationsByUserAccess(
      List<Publication> publications) {
    print('🚨🚨🚨 FILTERING PUBLICATIONS BY USER ACCESS - START 🚨🚨🚨');
    print('🚨🚨🚨 FILTERING PUBLICATIONS BY USER ACCESS - START 🚨🚨🚨');
    print('🚨🚨🚨 FILTERING PUBLICATIONS BY USER ACCESS - START 🚨🚨🚨');

    final userProducts = UserSession.instance.extensionProducts ?? [];

    print('=== OFFLINE DOWNLOAD FILTERING ===');
    print('Total publications: ${publications.length}');
    print('User extension products: $userProducts');
    print(
        'UserSession.instance.extensionProducts: ${UserSession.instance.extensionProducts}');
    print(
        'UserSession.instance.idToken: ${UserSession.instance.idToken != null ? "Present" : "NULL"}');

    // Check if user has any extension products
    if (userProducts.isEmpty) {
      print(
          '❌ No extension products found - user has no access to any publications');
      return [];
    }

    final accessiblePublications = <Publication>[];

    for (final publication in publications) {
      print('Checking publication: "${publication.title}"');
      print(
          '  Publication restrictPublicAccessIds: ${publication.restrictPublicAccessIds}');

      bool hasAccess = false;

      // PRIMARY: Check direct access via restrictPublicAccessIds from API
      if (publication.restrictPublicAccessIds.isEmpty) {
        // Empty restrictPublicAccessIds means truly open access (no restrictions)
        hasAccess = true;
        print(
            '  ✅ Publication has NO restrictions (empty restrictPublicAccessIds) - ALLOWING access');
      } else {
        // Check if user's extension_products contains any of the required IDs
        hasAccess = publication.restrictPublicAccessIds
            .any((restrictId) => userProducts.contains(restrictId));
        print(
            '  🔍 Checking if user extension_products $userProducts contains any of required IDs: ${publication.restrictPublicAccessIds}');
        print(
            '  📊 Direct restrictPublicAccessIds check result: ${hasAccess ? 'YES - USER HAS ACCESS' : 'NO - USER LACKS REQUIRED IDs'}');

        if (hasAccess) {
          // Find which specific ID granted access
          final matchingIds = publication.restrictPublicAccessIds
              .where((restrictId) => userProducts.contains(restrictId))
              .toList();
          print('  🎯 Access granted by matching ID(s): $matchingIds');
        }
      }

      print('  ⭐ FINAL ACCESS DECISION: ${hasAccess ? 'YES' : 'NO'}');

      if (hasAccess) {
        accessiblePublications.add(publication);
        print('  ✅ ADDED to download list');
      } else {
        print(
            '  ❌ SKIPPED - user extension_products do not match restrictPublicAccessIds');
      }
    }

    print('Final accessible publications: ${accessiblePublications.length}');
    print('Publication titles to download:');
    for (final pub in accessiblePublications) {
      print('  - ${pub.title}');
    }
    print('=== END FILTERING ===');

    print(
        '🚨🚨🚨 FILTERING RESULT: ${accessiblePublications.length} accessible publications 🚨🚨🚨');
    print(
        '🚨🚨🚨 FILTERING RESULT: ${accessiblePublications.length} accessible publications 🚨🚨🚨');
    print(
        '🚨🚨🚨 FILTERING RESULT: ${accessiblePublications.length} accessible publications 🚨🚨🚨');

    return accessiblePublications;
  }

  /// Save the list of accessible publications for offline use
  Future<void> _saveAccessiblePublicationsList(
      List<Publication> publications) async {
    final publicationsData = publications
        .map((p) => {
              'Id': p.id,
              'Title': p.title,
              'Ingress': p.ingress,
              'Url': p.url,
              'ImageUrl': p.imageUrl,
              'RestrictPublicAccessIds': p.restrictPublicAccessIds,
            })
        .toList();

    await LocalStorageService.writeJson(
        'offline_publications.json', publicationsData);
    print(
        'Saved ${publications.length} accessible publications for offline use');
  }

  /// Get offline publications list
  static Future<List<Publication>> getOfflinePublications() async {
    try {
      final data =
          await LocalStorageService.readJson('offline_publications.json');
      if (data is List) {
        return data.map((json) => Publication.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading offline publications: $e');
    }
    return [];
  }

  /// Check if offline data is available
  static Future<bool> hasOfflineData() async {
    try {
      final data =
          await LocalStorageService.readJson('offline_publications.json');
      return data != null && data is List && data.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear all offline data
  Future<void> clearOfflineData() async {
    try {
      // Clear publications list
      await LocalStorageService.clearFile('offline_publications.json');

      // Clear all cached publication data
      final publications = await getOfflinePublications();
      for (final pub in publications) {
        await LocalStorageService.clearFile('fullcontent_${pub.id}.json');
        await LocalStorageService.clearFile('pubimg_${pub.id}.img');
      }

      print('Cleared all offline data');
    } catch (e) {
      print('Error clearing offline data: $e');
    }
  }

  /// Download content only for a single publication
  Future<bool> downloadSinglePublicationContent(String publicationId) async {
    try {
      print('🚀 Downloading content for publication: $publicationId');
      await _publicationService.downloadAndCacheContentOnly(publicationId);

      // Update timestamp
      await _updateDownloadTimestamp(publicationId, 'content');

      print('✅ Successfully downloaded content for $publicationId');
      return true;
    } catch (e) {
      print('❌ Failed to download content for $publicationId: $e');
      return false;
    }
  }

  /// Download images for a single publication
  Future<bool> downloadSinglePublicationImages(String publicationId) async {
    try {
      print('🚀 Downloading images for publication: $publicationId');
      await _publicationService
          .downloadImagesForCachedPublication(publicationId);

      // Update timestamp
      await _updateDownloadTimestamp(publicationId, 'images');

      print('✅ Successfully downloaded images for $publicationId');
      return true;
    } catch (e) {
      print('❌ Failed to download images for $publicationId: $e');
      return false;
    }
  }

  /// Check if publication content is downloaded
  Future<bool> isPublicationContentDownloaded(String publicationId) async {
    try {
      final data =
          await LocalStorageService.readJson('fullcontent_$publicationId.json');
      return data != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if publication images are downloaded
  Future<bool> arePublicationImagesDownloaded(String publicationId) async {
    try {
      return await _publicationService
          .areImagesCachedForPublication(publicationId);
    } catch (e) {
      return false;
    }
  }

  /// Get last download timestamp for publication content/images
  Future<DateTime?> getLastDownloadTimestamp(
      String publicationId, String type) async {
    try {
      final timestamps =
          await LocalStorageService.readJson('download_timestamps.json') ?? {};
      final timestamp = timestamps['${publicationId}_$type'];
      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }
    } catch (e) {
      print('Error getting download timestamp: $e');
    }
    return null;
  }

  /// Update download timestamp
  Future<void> _updateDownloadTimestamp(
      String publicationId, String type) async {
    try {
      final timestamps =
          await LocalStorageService.readJson('download_timestamps.json') ?? {};
      timestamps['${publicationId}_$type'] = DateTime.now().toIso8601String();
      await LocalStorageService.writeJson(
          'download_timestamps.json', timestamps);
    } catch (e) {
      print('Error updating download timestamp: $e');
    }
  }
}

class DownloadProgress {
  final int currentItem;
  final int totalItems;
  final String currentTask;
  final double percentComplete;

  DownloadProgress({
    required this.currentItem,
    required this.totalItems,
    required this.currentTask,
  }) : percentComplete =
            totalItems > 0 ? (currentItem / totalItems) * 100 : 0.0;

  String get percentageString => '${percentComplete.toStringAsFixed(1)}%';

  String get progressText =>
      '$currentTask ($currentItem/$totalItems - $percentageString)';
}

class DownloadResult {
  int totalPublications = 0;
  int successfulDownloads = 0;
  int failedDownloads = 0;
  List<String> errors = [];

  bool get isSuccess => failedDownloads == 0 && successfulDownloads > 0;
  bool get hasErrors => errors.isNotEmpty;
}
