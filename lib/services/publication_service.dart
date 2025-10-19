import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import '../models/publication.dart';
import '../models/chapter.dart';
import '../models/subchapter.dart';
import '../models/subchapter_detail.dart';
import 'local_storage_service.dart';
import 'publication_access_service.dart';
import 'offline_download_service.dart';

class PublicationService {
  // HTTP client that accepts self-signed certificates for localhost
  late HttpClient _httpClient;

  // Helper to convert localhost URLs to work with Android emulator
  String _fixLocalhostUrl(String url) {
    // On Android emulator, localhost should be 10.0.2.2 to reach the host machine
    return url.replaceAll('localhost:44342', '10.0.2.2:44342');
  }

  PublicationService() {
    _httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Accept all certificates for localhost development
        return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
      };
  }

  void dispose() {
    _httpClient.close();
  }

  // Download and cache publication image
  Future<File?> downloadAndCacheImage(
      String imageUrl, String publicationId) async {
    if (imageUrl.isEmpty) return null;
    try {
      final url = Uri.parse("https://kompetansebiblioteket.no$imageUrl");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final filename = 'pubimg_$publicationId.img';
        await LocalStorageService.writeImage(filename, response.bodyBytes);
        return await LocalStorageService.readImageFile(filename);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  // Get cached image file for publication
  Future<File?> getCachedImageFile(String publicationId) async {
    final filename = 'pubimg_$publicationId.img';
    return await LocalStorageService.readImageFile(filename);
  }

  // Extract cached:// image URLs and their indices from content
  List<String> _extractCachedImageUrls(Map<String, dynamic> data) {
    final Set<String> cachedUrls = <String>{};

    void extractCachedUrls(dynamic value) {
      if (value is String) {
        final cachedRegex = RegExp(r'src=["\047](cached://[^"\047]+)["\047]',
            caseSensitive: false);
        final matches = cachedRegex.allMatches(value);
        for (final match in matches) {
          final url = match.group(1);
          if (url != null) {
            cachedUrls.add(url);
            print('🔍 Found cached URL: $url');
          }
        }
      } else if (value is Map<String, dynamic>) {
        value.values.forEach(extractCachedUrls);
      } else if (value is List) {
        value.forEach(extractCachedUrls);
      }
    }

    extractCachedUrls(data);
    print('📊 Found ${cachedUrls.length} cached:// URLs in content');
    return cachedUrls.toList();
  }

  // Find original URLs for cached:// references by looking at the publication's image mapping
  Future<List<String>> _findOriginalUrlsForCachedImages(
      Map<String, dynamic> data, String publicationId) async {
    final Set<String> originalUrls = <String>{};

    // Extract all cached:// URLs first
    final cachedUrls = _extractCachedImageUrls(data);
    print(
        '🔍 Attempting to find original URLs for ${cachedUrls.length} cached references');

    // Look for image mapping in the data structure
    void searchForImageMapping(dynamic value, String path) {
      if (value is Map<String, dynamic>) {
        // Look for potential image mapping structures
        value.forEach((key, val) {
          final keyLower = key.toString().toLowerCase();
          if (keyLower.contains('image') ||
              keyLower.contains('media') ||
              keyLower.contains('url')) {
            if (val is String &&
                val.startsWith('http') &&
                val.contains('/media/')) {
              originalUrls.add(val);
              print('🎯 Found original image URL at $path.$key: $val');
            }
          }
          searchForImageMapping(val, '$path.$key');
        });
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          searchForImageMapping(value[i], '$path[$i]');
        }
      } else if (value is String &&
          value.startsWith('http') &&
          value.contains('/media/')) {
        originalUrls.add(value);
        print('🎯 Found original image URL at $path: $value');
      }
    }

    searchForImageMapping(data, 'root');

    print(
        '🎯 Found ${originalUrls.length} original URLs from cached references');
    return originalUrls.toList();
  }

  // Create image files for all cached URLs found

  // Debug method to check HTML content
  void _debugHtmlContent(Map<String, dynamic> data) {
    int htmlFieldCount = 0;
    int totalImgTags = 0;
    int cachedImgTags = 0;

    void checkValue(dynamic value, String path) {
      if (value is String) {
        if (value.contains('<img')) {
          htmlFieldCount++;
          final imgRegex = RegExp(r'<img[^>]*>', caseSensitive: false);
          final matches = imgRegex.allMatches(value);
          totalImgTags += matches.length;

          // Count cached:// URLs
          final cachedRegex =
              RegExp(r'src=["\047]cached://', caseSensitive: false);
          final cachedMatches = cachedRegex.allMatches(value);
          cachedImgTags += cachedMatches.length;

          if (matches.isNotEmpty) {
            print('🔍 HTML field at $path: ${matches.length} img tags');
            for (final match in matches.take(2)) {
              print('   IMG: ${match.group(0)}');
            }
          }
        }
      } else if (value is Map<String, dynamic>) {
        value.forEach((key, val) => checkValue(val, '$path.$key'));
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          checkValue(value[i], '$path[$i]');
        }
      }
    }

    checkValue(data, 'root');
    print('🔍 HTML DEBUG SUMMARY:');
    print('   Fields with HTML content: $htmlFieldCount');
    print('   Total <img> tags found: $totalImgTags');
    print('   Already cached:// URLs: $cachedImgTags');
    print('   New URLs to download: ${totalImgTags - cachedImgTags}');
  }

  // Extract image URLs from full content data
  List<String> _extractImageUrls(Map<String, dynamic> data) {
    final Set<String> imageUrls = <String>{};

    void extractFromValue(dynamic value) {
      if (value is String) {
        // Look for img tags in HTML content
        final imgRegex = RegExp(r'<img[^>]+src=["\047]([^"\047]+)["\047][^>]*>',
            caseSensitive: false);
        final matches = imgRegex.allMatches(value);
        for (final match in matches) {
          final url = match.group(1);
          if (url != null && url.isNotEmpty) {
            print('🔍 Found image URL in HTML: $url');

            // Skip cached:// URLs - they should not be processed here
            if (url.startsWith('cached://')) {
              print('⏭️ Skipping cached URL: $url');
              continue;
            }

            // Convert relative URLs to absolute URLs (using 10.0.2.2 for Android emulator)
            if (url.startsWith('/')) {
              final absoluteUrl = 'https://10.0.2.2:44342$url';
              imageUrls.add(absoluteUrl);
              print('➡️ Converted to absolute: $absoluteUrl');
            } else if (!url.startsWith('http')) {
              final absoluteUrl = 'https://10.0.2.2:44342/$url';
              imageUrls.add(absoluteUrl);
              print('➡️ Converted to absolute: $absoluteUrl');
            } else {
              imageUrls.add(url);
              print('➡️ Using as-is: $url');
            }
          }
        }

        // Also look for direct image URLs
        final urlRegex = RegExp(
            r'https?://[^\s<>"\047]+\.(jpg|jpeg|png|gif|webp)',
            caseSensitive: false);
        final urlMatches = urlRegex.allMatches(value);
        for (final match in urlMatches) {
          final url = match.group(0);
          if (url != null) {
            imageUrls.add(url);
          }
        }
      } else if (value is Map<String, dynamic>) {
        value.values.forEach(extractFromValue);
      } else if (value is List) {
        value.forEach(extractFromValue);
      }
    }

    extractFromValue(data);
    print(
        '📊 Extracted ${imageUrls.length} unique image URLs from content data');
    if (imageUrls.isNotEmpty) {
      print('📋 Image URLs list:');
      imageUrls.toList().asMap().forEach((index, url) {
        print('  [$index] $url');
      });
    }
    return imageUrls.toList();
  }

  // Download and cache a single image for content
  Future<void> _downloadAndCacheContentImage(
      String imageUrl, String publicationId, int index) async {
    HttpClient? httpClient;
    try {
      print('🖼️ Downloading content image $index: $imageUrl');

      // Use custom HTTP client for our localhost URLs
      httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30)
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          print(
              '🔒 SSL certificate check for $host:$port - allowing localhost');
          return host == 'localhost' ||
              host == '127.0.0.1' ||
              host == '10.0.2.2';
        };

      final Uri uri = Uri.parse(imageUrl);
      print('📡 Making HTTP request to: $uri');

      final HttpClientRequest request = await httpClient.getUrl(uri);
      request.headers.set('Accept', 'image/*');
      request.headers.set('User-Agent', 'Flutter-App/1.0');

      final HttpClientResponse response = await request.close();
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response headers: ${response.headers}');

      // Extra debug: print first 100 bytes of response
      final List<int> bytes = await response.expand((chunk) => chunk).toList();
      print('📥 Response body length: ${bytes.length}');
      if (bytes.isNotEmpty) {
        print('📥 First 20 bytes: ${bytes.take(20).toList()}');
      }

      if (response.statusCode == 200) {
        if (bytes.isEmpty) {
          print('💥 ERROR: Empty response body for image $imageUrl');
          throw Exception('Empty response body');
        }

        final filename = 'content_img_${publicationId}_$index.img';
        print('💾 Attempting to write image file: $filename');
        await LocalStorageService.writeImage(
            filename, Uint8List.fromList(bytes));
        print('✅ Successfully cached image: $filename (${bytes.length} bytes)');

        // Verify the file was actually saved
        final savedFile = await LocalStorageService.readImageFile(filename);
        if (savedFile != null) {
          print('✅ Verified cached file exists: ${savedFile.path}');
          final fileExists = await savedFile.exists();
          final fileSize = fileExists ? await savedFile.length() : 0;
          print('✅ File exists: $fileExists, size: $fileSize bytes');
        } else {
          print('💥 ERROR: File was not properly saved: $filename');
          throw Exception('File was not properly saved');
        }
      } else {
        print(
            '💥 ERROR: HTTP ${response.statusCode}: ${response.reasonPhrase}');
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('💥 Error downloading image $imageUrl: $e');
      rethrow; // Re-throw to be caught by the caller
    } finally {
      httpClient?.close();
    }
  }

  // Get cached content image file
  Future<File?> getCachedContentImageFile(
      String publicationId, int index) async {
    final filename = 'content_img_${publicationId}_$index.img';
    print('🔍 Looking for cached image file: $filename');

    // Special debug for the specific problematic image
    if (publicationId == '25621b7a-c477-47b6-ac3f-b6553f8a7e95' &&
        index == 15) {
      print('🎯 SPECIAL DEBUG: This is the problematic image file: $filename');
      print('   Publication ID: $publicationId');
      print('   Image Index: $index');
    }

    // FIXED: Use static method with support directory (same as saving)
    final file = await LocalStorageService.readImageFile(filename);
    if (file != null) {
      print('✅ Found cached image file: ${file.path}');
      if (publicationId == '25621b7a-c477-47b6-ac3f-b6553f8a7e95' &&
          index == 15) {
        print('🎯 SUCCESS: The problematic image file EXISTS at: ${file.path}');
      }
    } else {
      print('❌ Cached image file not found: $filename');
      if (publicationId == '25621b7a-c477-47b6-ac3f-b6553f8a7e95' &&
          index == 15) {
        print('🎯 PROBLEM: The specific image file is MISSING: $filename');
      }
      print('💡 Suggestion: Re-run offline download to cache images properly');
    }

    return file;
  }

  // Check if images are cached for a publication
  Future<bool> areImagesCachedForPublication(String publicationId) async {
    try {
      print(
          '🔍 areImagesCachedForPublication: Checking images for $publicationId');

      // Get fresh data from API to find original image URLs
      final freshData = await fetchFullPublicationFromApi(publicationId);
      if (freshData == null) {
        print(
            '❌ areImagesCachedForPublication: Could not fetch fresh data from API');
        return false;
      }

      // Extract original HTTP image URLs before they get converted to cached://
      final originalImageUrls = _extractImageUrls(freshData);
      print(
          '🔍 areImagesCachedForPublication: Found ${originalImageUrls.length} original images in API data');

      // If no images expected, return true
      if (originalImageUrls.isEmpty) {
        print(
            '🔍 areImagesCachedForPublication: No images expected, returning true');
        return true;
      }

      // Check if all image files exist
      for (int i = 0; i < originalImageUrls.length; i++) {
        final imageFilename = 'content_img_${publicationId}_$i.img';
        final imageFile =
            await LocalStorageService.readImageFile(imageFilename);
        if (imageFile == null) {
          print(
              '❌ areImagesCachedForPublication: Missing image file $i: $imageFilename');
          return false;
        }
      }

      print(
          '✅ areImagesCachedForPublication: All ${originalImageUrls.length} images are cached for publication $publicationId');
      return true;
    } catch (e) {
      print('💥 areImagesCachedForPublication ERROR: $e');
      return false;
    }
  }

  // Process HTML content to use cached images
  String _processHtmlForCachedImages(String htmlContent, String publicationId,
      Map<String, int> imageUrlToIndex) {
    String processedHtml = htmlContent;

    print('🔧 Processing HTML for cached images in publication $publicationId');
    print('🔧 ImageUrlToIndex mapping has ${imageUrlToIndex.length} entries');

    // Debug: Print current mapping
    print('🔧 Current imageUrlToIndex mapping:');
    imageUrlToIndex.forEach((url, index) {
      print('  $index: $url');
    });

    // Replace image URLs in HTML with cached image references
    // Use multiple regex patterns to catch different image tag formats
    final regexPatterns = [
      RegExp(r'<img([^>]*?)src=["\047]([^"\047]+)["\047]([^>]*?)>',
          caseSensitive: false),
      RegExp(r'<img([^>]*?)src=([^\s>]+)([^>]*?)>', caseSensitive: false),
    ];

    for (final imgRegex in regexPatterns) {
      processedHtml = processedHtml.replaceAllMapped(imgRegex, (match) {
        final beforeSrc = match.group(1) ?? '';
        final originalUrl = match.group(2) ?? '';
        final afterSrc = match.group(3) ?? '';

        // Skip if this is already a cached reference
        if (originalUrl.startsWith('cached://')) {
          print('🔧 Skipping already cached URL: $originalUrl');
          return match.group(0)!;
        }

        // Skip if URL contains quotes or other malformed characters
        if (originalUrl.contains('"') || originalUrl.contains("'")) {
          print('🔧 Skipping malformed quoted URL: $originalUrl');
          return match.group(0)!;
        }

        print('🔧 Processing image with regex: $originalUrl');

        // Convert to absolute URL if relative (using 10.0.2.2 for Android emulator)
        String absoluteUrl = originalUrl;
        if (originalUrl.startsWith('/')) {
          absoluteUrl = 'https://10.0.2.2:44342$originalUrl';
          print('🔧 Converted relative URL to: $absoluteUrl');
        } else if (!originalUrl.startsWith('http')) {
          absoluteUrl = 'https://10.0.2.2:44342/$originalUrl';
          print('🔧 Converted relative URL to: $absoluteUrl');
        }

        // Check if we have this image cached
        final imageIndex = imageUrlToIndex[absoluteUrl];
        print(
            '🔧 Looking for $absoluteUrl in cache mapping: ${imageIndex != null ? 'found at index $imageIndex' : 'not found'}');

        if (imageIndex != null) {
          final cachedRef = 'cached://$publicationId/$imageIndex';
          print('🔧 Replacing with cached reference: $cachedRef');
          // Replace with cached image reference
          return '<img${beforeSrc}src="$cachedRef"$afterSrc>';
        }

        print('🔧 Keeping original URL: $originalUrl');
        // If not cached, keep original URL
        return match.group(0)!;
      });
    }

    return processedHtml;
  }

  // Sjekk om full content cache finnes for en publikasjon
  Future<bool> hasFullContentCache(String publicationId) async {
    final filename = 'fullcontent_$publicationId.json';
    final data = await LocalStorageService.readJson(filename);
    return data != null;
  }

  // Fetch full publication data from new API endpoint
  Future<Map<String, dynamic>?> fetchFullPublicationFromApi(
      String publicationId) async {
    final urls = [
      'https://localhost:44342/umbraco/api/AppApi/GetPublicationsByPublicationId?publicationId=$publicationId',
      'https://10.0.2.2:44342/umbraco/api/AppApi/GetPublicationsByPublicationId?publicationId=$publicationId',
      'https://127.0.0.1:44342/umbraco/api/AppApi/GetPublicationsByPublicationId?publicationId=$publicationId',
      'http://localhost:44342/umbraco/api/AppApi/GetPublicationsByPublicationId?publicationId=$publicationId',
      'http://10.0.2.2:44342/umbraco/api/AppApi/GetPublicationsByPublicationId?publicationId=$publicationId',
      'http://127.0.0.1:44342/umbraco/api/AppApi/GetPublicationsByPublicationId?publicationId=$publicationId',
    ];

    for (String url in urls) {
      try {
        print('Trying publication API URL: $url');

        dynamic data;
        if (url.startsWith('https://')) {
          // Use custom HTTP client for HTTPS URLs
          final request = await _httpClient.getUrl(Uri.parse(url));
          request.headers.set('Content-Type', 'application/json');
          final httpResponse =
              await request.close().timeout(const Duration(seconds: 10));

          if (httpResponse.statusCode == 200) {
            final responseBody =
                await httpResponse.transform(utf8.decoder).join();
            data = json.decode(responseBody);
            print('Success fetching publication data from: $url');
          } else {
            continue;
          }
        } else {
          // Use regular http package for HTTP URLs
          final response = await http.get(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            data = json.decode(response.body);
            print('Success fetching publication data from: $url');
          } else {
            continue;
          }
        }

        // Handle both List and Map responses
        if (data is List && data.isNotEmpty) {
          // If API returns array, take the first item
          print(
              'API returned array with ${data.length} items, taking first item');
          return data[0] as Map<String, dynamic>;
        } else if (data is Map<String, dynamic>) {
          // If API returns object directly
          print('API returned single object');
          return data;
        } else {
          print('Unexpected data type: ${data.runtimeType}');
          continue;
        }
      } catch (e) {
        print('Error fetching from $url: $e');
        continue;
      }
    }

    throw Exception('Failed to fetch publication data from all API endpoints');
  }

  // Last ned og cache full content for en publikasjon using new API
  Future<void> downloadAndCacheFullContent(String publicationId) async {
    try {
      print('🚀 STARTING downloadAndCacheFullContent for ID: $publicationId');
      print('🧪 TESTING: Attempting to download one test image first...');

      // TEST: Try to download one image to verify connectivity
      const testUrl = 'https://localhost:44342/media/s0vagh2n/p1_05_f1.gif';
      final fixedTestUrl = _fixLocalhostUrl(testUrl);
      print('🔧 Fixed test URL: $testUrl -> $fixedTestUrl');
      try {
        await _downloadAndCacheContentImage(fixedTestUrl, publicationId, 999);
        print('✅ TEST: Successfully downloaded test image from $fixedTestUrl');
      } catch (e) {
        print('❌ TEST: Failed to download test image: $e');
      }
      print('Fetching full publication data for ID: $publicationId');
      final data = await fetchFullPublicationFromApi(publicationId);
      print('✅ Successfully fetched data from API');

      if (data != null) {
        print('🔍 Data received, analyzing image content...');
        _debugHtmlContent(data);

        // First, check if we have original HTTP images to download
        // Note: We should get original URLs from fresh API data, not potentially cached data
        final originalImageUrls = _extractImageUrls(data);
        print(
            'Found ${originalImageUrls.length} original HTTP image URLs from API data');

        // Also check if we have cached:// images that need original URLs
        final cachedUrls = _extractCachedImageUrls(data);
        print('Found ${cachedUrls.length} cached:// image references');

        Map<String, int> imageUrlToIndex = {};
        int totalImages = 0;
        int successCount = 0;
        int failCount = 0;

        // Process original HTTP images
        if (originalImageUrls.isNotEmpty) {
          print(
              '🚀 Downloading ${originalImageUrls.length} original images...');

          for (int i = 0; i < originalImageUrls.length; i++) {
            final url = originalImageUrls[i];
            final fixedUrl = _fixLocalhostUrl(url);
            imageUrlToIndex[url] = totalImages;
            print('📥 Downloading image ${totalImages + 1}: $url -> $fixedUrl');

            try {
              await _downloadAndCacheContentImage(
                  fixedUrl, publicationId, totalImages);
              successCount++;
              print('✅ Image ${totalImages + 1} downloaded successfully');
            } catch (e) {
              failCount++;
              print('❌ Image ${totalImages + 1} failed: $e');
            }
            totalImages++;
          }
        }

        // Process cached:// URLs - try to find and download their originals
        if (cachedUrls.isNotEmpty) {
          print('🎯 Processing ${cachedUrls.length} cached:// references...');
          final originalUrlsFromCached =
              await _findOriginalUrlsForCachedImages(data, publicationId);

          for (int i = 0; i < originalUrlsFromCached.length; i++) {
            final url = originalUrlsFromCached[i];
            if (!imageUrlToIndex.containsKey(url)) {
              imageUrlToIndex[url] = totalImages;
              print('📥 Downloading cached ref image ${totalImages + 1}: $url');

              try {
                await _downloadAndCacheContentImage(
                    url, publicationId, totalImages);
                successCount++;
                print(
                    '✅ Cached ref image ${totalImages + 1} downloaded successfully');
              } catch (e) {
                failCount++;
                print('❌ Cached ref image ${totalImages + 1} failed: $e');
              }
              totalImages++;
            }
          }
        }

        print('🎯 Image download completed for publication $publicationId:');
        print('   📊 Total images processed: $totalImages');
        print('   ✅ Success: $successCount images');
        print('   ❌ Failed: $failCount images');

        // Separate HTTP URLs from cached:// URLs

        print('� URL Analysis:');
        print(
            '   Original HTTP URLs from _extractImageUrls: ${originalImageUrls.length}');
        print(
            '   Cached URLs from _extractCachedImageUrls: ${cachedUrls.length}');

        // NEW APPROACH: Always check if images are actually cached before skipping download
        print('🔍 Checking if images are actually cached...');
        final imagesActuallyCached =
            await areImagesCachedForPublication(publicationId);
        print('🔍 Images actually cached result: $imagesActuallyCached');

        // If images are not actually cached, we need to download them using the discovered URLs
        if (!imagesActuallyCached && originalImageUrls.isNotEmpty) {
          print(
              '🔍 Images not cached, proceeding to download using original HTTP URLs...');

          // Use the originally extracted HTTP URLs for download
          print('🔍 Found ${originalImageUrls.length} HTTP URLs to download');
          for (int i = 0; i < originalImageUrls.length; i++) {
            print('  [$i]: ${originalImageUrls[i]}');
          }

          // Download all the original HTTP URLs we found
          for (int i = 0; i < originalImageUrls.length; i++) {
            final url = originalImageUrls[i];
            imageUrlToIndex[url] = totalImages;

            print('📥 Downloading image ${totalImages + 1}: $url');
            try {
              await _downloadAndCacheContentImage(
                  url, publicationId, totalImages);
              successCount++;
              print('✅ Image ${totalImages + 1} downloaded successfully');
            } catch (e) {
              failCount++;
              print('❌ Image ${totalImages + 1} failed: $e');
            }
            totalImages++;
          }

          print('🎯 Image download completed for cached references:');
          print('   📊 Total images processed: $totalImages');
          print('   ✅ Success: $successCount images');
          print('   ❌ Failed: $failCount images');
        }

        // Process the data to update HTML content with cached image references
        final processedData =
            _processDataForCachedImages(data, publicationId, imageUrlToIndex);

        final filename = 'fullcontent_$publicationId.json';
        await LocalStorageService.writeJson(filename, processedData);
        print(
            'Full publication data cached to $filename with $totalImages images');

        print(' Completed downloadAndCacheFullContent for $publicationId');
      } else {
        throw Exception('No data received from API');
      }
    } catch (e) {
      print('Error downloading full content: $e');
      throw Exception('Could not fetch full publication data: $e');
    }
  }

  // Last ned og cache kun innhold (uten bilder) for en publikasjon
  Future<void> downloadAndCacheContentOnly(String publicationId) async {
    try {
      print('🚀 STARTING downloadAndCacheContentOnly for ID: $publicationId');
      print('Fetching full publication data for ID: $publicationId');
      final data = await fetchFullPublicationFromApi(publicationId);
      print('✅ Successfully fetched data from API');

      if (data != null) {
        print('📄 Saving content data without downloading images...');

        // Save content without processing images - just store raw API data
        final filename = 'fullcontent_$publicationId.json';
        await LocalStorageService.writeJson(filename, data);
        print('Content-only data cached to $filename');

        print('✅ Completed downloadAndCacheContentOnly for $publicationId');
      } else {
        throw Exception('No data received from API');
      }
    } catch (e) {
      print('Error downloading content only: $e');
      throw Exception('Could not fetch publication data: $e');
    }
  }

  // Last ned bilder for en allerede cachet publikasjon
  Future<void> downloadImagesForCachedPublication(String publicationId) async {
    try {
      print(
          '🚀 STARTING downloadImagesForCachedPublication for ID: $publicationId');

      // Check if we have cached content first
      final filename = 'fullcontent_$publicationId.json';
      Map<String, dynamic>? data;
      try {
        data = await LocalStorageService.readJson(filename);
      } catch (e) {
        throw Exception(
            'No cached content found for publication $publicationId. Download content first.');
      }

      if (data != null) {
        print('🔍 Found cached content, analyzing image content...');
        _debugHtmlContent(data);

        // Extract image URLs from cached data
        final originalImageUrls = _extractImageUrls(data);
        print('📸 Found ${originalImageUrls.length} images to download');

        // Create mapping for image indices
        final imageUrlToIndex = <String, int>{};
        for (int i = 0; i < originalImageUrls.length; i++) {
          imageUrlToIndex[originalImageUrls[i]] = i;
        }

        // Download all images
        int totalImages = 0;
        for (int i = 0; i < originalImageUrls.length; i++) {
          final originalUrl = originalImageUrls[i];
          final fixedUrl = _fixLocalhostUrl(originalUrl);

          try {
            print(
                '📥 Downloading image ${i + 1}/${originalImageUrls.length}: $fixedUrl');
            await _downloadAndCacheContentImage(fixedUrl, publicationId, i);
            totalImages++;
          } catch (e) {
            print('❌ Failed to download image $fixedUrl: $e');
          }
        }

        // Now process the data to use cached images and save updated version
        final processedData =
            _processDataForCachedImages(data, publicationId, imageUrlToIndex);
        await LocalStorageService.writeJson(filename, processedData);

        print(
            '✅ Downloaded $totalImages images and updated cached content for $publicationId');
      } else {
        throw Exception('No cached content data found');
      }
    } catch (e) {
      print('Error downloading images for cached publication: $e');
      throw Exception('Could not download images: $e');
    }
  }

  // Process the entire data structure to update HTML content with cached image references
  Map<String, dynamic> _processDataForCachedImages(Map<String, dynamic> data,
      String publicationId, Map<String, int> imageUrlToIndex) {
    Map<String, dynamic> processedData = Map<String, dynamic>.from(data);

    void processValue(dynamic key, dynamic value, Map<String, dynamic> parent) {
      if (value is String && value.contains('<img')) {
        parent[key] =
            _processHtmlForCachedImages(value, publicationId, imageUrlToIndex);
      } else if (value is Map<String, dynamic>) {
        value.forEach((k, v) => processValue(k, v, value));
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          if (value[i] is Map<String, dynamic>) {
            (value[i] as Map<String, dynamic>)
                .forEach((k, v) => processValue(k, v, value[i]));
          } else if (value[i] is String &&
              (value[i] as String).contains('<img')) {
            value[i] = _processHtmlForCachedImages(
                value[i], publicationId, imageUrlToIndex);
          }
        }
      }
    }

    processedData
        .forEach((key, value) => processValue(key, value, processedData));
    return processedData;
  }

  // Last ned og cache alt (publikasjoner, kapitler, subkapitler)
  Future<void> downloadAndCacheAll() async {
    // 1. Last ned publikasjoner
    final pubs = await loadPublicationsFromApi();
    await LocalStorageService.writeJson(
        'publications.json',
        pubs
            .map((p) => {
                  'Id': p.id,
                  'Title': p.title,
                  'Ingress': p.ingress,
                  'Url': p.url,
                  'ImageUrl': p.imageUrl,
                })
            .toList());

    // 2. Last ned alle kapitler for hver publikasjon
    List<Map<String, dynamic>> allChapters = [];
    for (final pub in pubs) {
      final chapters = await fetchChaptersFromApi(pub.id);
      for (final c in chapters) {
        allChapters.add({
          'bookId': pub.id,
          'chapter': {
            'ID': c.id,
            'Title': c.title,
            'Url': c.url,
          }
        });
      }
    }
    await LocalStorageService.writeJson('chapters.json', allChapters);

    // 3. Last ned alle subchapters for hver kapittel
    List<Map<String, dynamic>> allSubChapters = [];
    for (final ch in allChapters) {
      final chapterId = ch['chapter']['ID'] as String;
      final subChapters = await fetchSubChaptersFromApi(chapterId);
      for (final s in subChapters) {
        allSubChapters.add({
          'chapterId': chapterId,
          'subchapter': {
            'ID': s.id,
            'Title': s.title,
            'webUrl': s.webUrl,
            'Number': s.number,
          }
        });
      }
    }
    await LocalStorageService.writeJson('subchapters.json', allSubChapters);
  }

  // Hent publikasjoner fra API (ikke cache)
  Future<List<Publication>> loadPublicationsFromApi() async {
    final url = Uri.parse(
        'https://kompetansebiblioteket.no/SkarlandAppService.asmx/BookList');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Publication.fromJson(json)).toList();
    } else {
      throw Exception('Kunne ikke hente publikasjoner');
    }
  }

  // Hent kapitler fra API (ikke cache)
  Future<List<Chapter>> fetchChaptersFromApi(String bookId) async {
    final url = Uri.parse(
        "https://kompetansebiblioteket.no/SkarlandAppService.asmx/BookChapters?bookID=$bookId");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Chapter.fromJson(json)).toList();
    } else {
      throw Exception("Kunne ikke hente kapitler");
    }
  }

  // Hent subchapters fra API (ikke cache)
  Future<List<SubChapter>> fetchSubChaptersFromApi(String chapterId) async {
    String id = chapterId;
    if (!id.startsWith('{')) id = '{$id';
    if (!id.endsWith('}')) id = '$id}';
    final url = Uri.parse(
        'https://kompetansebiblioteket.no/SkarlandAppService.asmx/BookSubChapterList?chapterID=$id');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SubChapter.fromJson(json)).toList();
    } else {
      throw Exception('Kunne ikke hente underkapitler');
    }
  }

  // Hent detaljer for et subkapittel
  Future<SubChapterDetail> fetchSubChapterDetail(String subchapterId) async {
    String id = subchapterId;
    if (!id.startsWith('{')) id = '{$id';
    if (!id.endsWith('}')) id = '$id}';
    final url = Uri.parse(
        'https://kompetansebiblioteket.no/SkarlandAppService.asmx/BookSubChapter?subchapterID=$id');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return SubChapterDetail.fromJson(data);
    } else {
      throw Exception('Kunne ikke hente subkapittel-detaljer');
    }
  }

  // (Fjernet: fetchSubChapters som brukte API)

  // Load publications with offline support
  Future<List<Publication>> loadPublications() async {
    // First try to load from offline storage
    if (await OfflineDownloadService.hasOfflineData()) {
      print('Loading publications from offline storage');
      final offlinePublications =
          await OfflineDownloadService.getOfflinePublications();
      if (offlinePublications.isNotEmpty) {
        return offlinePublications;
      }
    }

    // Fallback to assets
    print('Loading publications from assets (fallback)');
    final String response =
        await rootBundle.loadString('assets/publications.json');
    final List<dynamic> data = jsonDecode(response);

    // Filtrer publikasjoner basert på brukerens tilganger
    final filteredData = PublicationAccessService.filterPublicationsByAccess(
        data.cast<Map<String, dynamic>>());

    return filteredData.map((json) => Publication.fromJson(json)).toList();
  }

  // Hent kapitler KUN fra lagret fullcontent-fil
  Future<List<Chapter>> fetchChapters(String bookId) async {
    final fullContentFile = 'fullcontent_$bookId.json';
    final fullContent = await LocalStorageService.readJson(fullContentFile);
    print(
        'Leser fra $fullContentFile, data: ${fullContent != null ? 'OK' : 'null'}');
    if (fullContent == null) {
      throw Exception('Ingen lagret fullcontent-data for denne publikasjonen.');
    }

    List<dynamic> chaptersJson = [];

    if (fullContent is Map<String, dynamic>) {
      // Check various possible chapter field names from new API
      if (fullContent['Chapters'] != null) {
        chaptersJson = fullContent['Chapters'];
        print('Found chapters in: Chapters');
      } else if (fullContent['chapters'] != null) {
        chaptersJson = fullContent['chapters'];
        print('Found chapters in: chapters');
      } else if (fullContent['Chapter'] != null) {
        chaptersJson = fullContent['Chapter'] is List
            ? fullContent['Chapter']
            : [fullContent['Chapter']];
        print('Found chapters in: Chapter');
      } else if (fullContent['Subchapters'] != null) {
        chaptersJson = fullContent['Subchapters'];
        print('Found chapters in: Subchapters');
      } else if (fullContent['subchapters'] != null) {
        chaptersJson = fullContent['subchapters'];
        print('Found chapters in: subchapters');
      } else if (fullContent['Publication'] != null &&
          fullContent['Publication']['Chapters'] != null) {
        chaptersJson = fullContent['Publication']['Chapters'];
        print('Found chapters in: Publication.Chapters');
      } else if (fullContent['Data'] != null &&
          fullContent['Data']['Chapters'] != null) {
        chaptersJson = fullContent['Data']['Chapters'];
        print('Found chapters in: Data.Chapters');
      }
      // If still no chapters found, try to extract from publication content structure
      else if (fullContent['Content'] != null) {
        var content = fullContent['Content'];
        if (content is Map && content['Chapters'] != null) {
          chaptersJson = content['Chapters'];
          print('Found chapters in: Content.Chapters');
        }
      }
    } else if (fullContent is List) {
      chaptersJson = fullContent;
      print('Found chapters as direct list');
    }

    if (chaptersJson.isEmpty) {
      print(
          'Full content structure: ${json.encode(fullContent).substring(0, 500)}...');
      throw Exception(
          'Ingen kapitler funnet i fullcontent-data. Sjekk datastrukturen.');
    }

    print('Found ${chaptersJson.length} chapters to process');
    return chaptersJson.map((json) => Chapter.fromJson(json)).toList();
  }

  // Hent subchapters KUN fra lagret fullcontent-fil
  Future<List<SubChapter>> fetchSubChapters(
      String chapterId, String bookId) async {
    final fullContentFile = 'fullcontent_$bookId.json';
    final fullContent = await LocalStorageService.readJson(fullContentFile);
    print(
        'Fetching ALL subchapters for bookId: $bookId (ignoring chapterId: $chapterId)');
    if (fullContent == null) {
      throw Exception('Ingen lagret fullcontent-data for denne publikasjonen.');
    }

    List<dynamic> chaptersJson = [];

    if (fullContent is Map<String, dynamic>) {
      // Check various possible chapter field names from new API
      if (fullContent['Chapters'] != null) {
        chaptersJson = fullContent['Chapters'];
        print('Found chapters in: Chapters');
      } else if (fullContent['chapters'] != null) {
        chaptersJson = fullContent['chapters'];
        print('Found chapters in: chapters');
      } else if (fullContent['Chapter'] != null) {
        chaptersJson = fullContent['Chapter'] is List
            ? fullContent['Chapter']
            : [fullContent['Chapter']];
        print('Found chapters in: Chapter');
      } else if (fullContent['Subchapters'] != null) {
        chaptersJson = fullContent['Subchapters'];
        print('Found chapters in: Subchapters');
      } else if (fullContent['subchapters'] != null) {
        chaptersJson = fullContent['subchapters'];
        print('Found chapters in: subchapters');
      }
    } else if (fullContent is List) {
      chaptersJson = fullContent;
      print('Found chapters as direct list');
    }

    if (chaptersJson.isEmpty) {
      throw Exception('Ingen subkapitler funnet i fullcontent-data.');
    }

    print('Returning ALL ${chaptersJson.length} chapters as subchapters');

    // Return ALL chapters as subchapters - each "Subchapter" from the API is a content item
    return chaptersJson.map((json) => SubChapter.fromJson(json)).toList();
  }

  // Get cached full content for inspection
  Future<Map<String, dynamic>?> getCachedFullContent(
      String publicationId) async {
    try {
      final filename = 'fullcontent_$publicationId.json';
      print('📁 Looking for cached content file: $filename');
      final data = await LocalStorageService.readJson(filename);
      if (data != null) {
        print('📁 Found cached content for publication $publicationId');

        // Debug: Check for malformed cached references
        final jsonString = jsonEncode(data);

        // Check for truncated cached references (shorter than expected UUID length)
        final truncatedRefs = RegExp(r'cached://[a-f0-9-]{1,35}(?![a-f0-9-/])')
            .allMatches(jsonString);
        if (truncatedRefs.isNotEmpty) {
          print('! Found ${truncatedRefs.length} malformed cached references:');
          for (final match in truncatedRefs.take(5)) {
            print('  - ${match.group(0)}');
          }

          // Show context for debugging
          final sampleRef = truncatedRefs.first.group(0);
          final sampleStart = jsonString.indexOf(sampleRef!);
          final contextStart = (sampleStart - 50).clamp(0, jsonString.length);
          final contextEnd =
              (sampleStart + sampleRef.length + 50).clamp(0, jsonString.length);
          final context = jsonString.substring(contextStart, contextEnd);
          print('  Context sample: ...$context...');
        }

        // Check for cached references missing index part
        final missingIndexRefs =
            RegExp(r'cached://[a-f0-9-]{36}(?![/])').allMatches(jsonString);
        if (missingIndexRefs.isNotEmpty) {
          print(
              '⚠️ Found ${missingIndexRefs.length} cached references missing index:');
          for (final match in missingIndexRefs.take(3)) {
            print('  - ${match.group(0)}');
          }
        }

        // Debug: Show all cached:// references found
        final allCachedRefs =
            RegExp(r'cached://[^"\s]+').allMatches(jsonString);
        if (allCachedRefs.isNotEmpty) {
          print('📋 All cached references found (${allCachedRefs.length}):');
          final refSet = <String>{};
          for (final match in allCachedRefs) {
            refSet.add(match.group(0)!);
          }
          for (final ref in refSet.take(10)) {
            // Show first 10 unique references
            print('  - $ref');
          }
          if (refSet.length > 10) {
            print('  ... and ${refSet.length - 10} more');
          }
        }

        return data;
      }
      print('📁 No cached content found for publication $publicationId');
      return null;
    } catch (e) {
      print('❌ Error reading cached content: $e');
      return null;
    }
  }

  // Fix malformed cached references in cached content
  Future<bool> fixMalformedCachedReferences(String publicationId) async {
    try {
      print(
          '🔧 Attempting to fix malformed cached references for publication: $publicationId');

      final filename = 'fullcontent_$publicationId.json';
      final data = await LocalStorageService.readJson(filename);

      if (data == null) {
        print('❌ No cached content found to fix');
        return false;
      }

      final jsonString = jsonEncode(data);

      // Look for malformed cached references that need fixing
      final malformedPattern =
          RegExp(r'cached://[a-f0-9-]{1,35}(?![a-f0-9-/])');
      final matches = malformedPattern.allMatches(jsonString);

      if (matches.isEmpty) {
        print('✅ No malformed cached references found to fix');
        return true;
      }

      print('🔧 Found ${matches.length} malformed cached references to fix');

      // Since the cached references are corrupted, we need to re-download and re-cache
      // the publication content to get properly formatted cached references
      print(
          '🔄 Re-downloading publication content to fix cached references...');

      // Clear the corrupted cached content
      await LocalStorageService.clearFile(filename);

      // Re-download and cache the publication content
      await downloadAndCacheFullContent(publicationId);

      print('✅ Successfully fixed malformed cached references');
      return true;
    } catch (e) {
      print('❌ Error fixing malformed cached references: $e');
      return false;
    }
  }

  // Clear cached images for a specific publication
  Future<void> clearCachedImagesForPublication(String publicationId) async {
    try {
      print('🧹 Clearing cached images for publication: $publicationId');

      // Clear the full content cache (which contains malformed cached references)
      final fullContentFilename = 'fullcontent_$publicationId.json';
      await LocalStorageService.clearFile(fullContentFilename);
      print('🧹 Cleared cached content file: $fullContentFilename');

      // Clear the publication image cache
      final pubImageFilename = 'pubimg_$publicationId.img';
      await LocalStorageService.clearFile(pubImageFilename);
      print('🧹 Cleared publication image file: $pubImageFilename');

      // Clear any cached content images for this publication
      // We'll iterate through common patterns
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      if (await dir.exists()) {
        await for (FileSystemEntity entity in dir.list()) {
          if (entity is File) {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            // Clear any cached image files that might belong to this publication
            if (fileName.startsWith('img_${publicationId}_') ||
                fileName.contains(publicationId)) {
              try {
                await entity.delete();
                print('🧹 Deleted cached file: $fileName');
              } catch (e) {
                print('⚠️ Could not delete file $fileName: $e');
              }
            }
          }
        }
      }

      print('✅ Cache clearing completed for publication: $publicationId');
    } catch (e) {
      print('❌ Error clearing cached images: $e');
    }
  }

  // Get cached publications (used by publication_list_screen)
  Future<List<Publication>> getCachedPublications() async {
    try {
      final cachedData =
          await LocalStorageService.readJson('cached_publications.json');
      if (cachedData != null && cachedData is List) {
        return cachedData.map((json) => Publication.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading cached publications: $e');
    }
    return [];
  }
}
