import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/new_publication.dart';
import 'api_client.dart';

class NewPublicationService {
  static NewPublicationService? _instance;
  static NewPublicationService get instance {
    _instance ??= NewPublicationService._();
    return _instance!;
  }

  NewPublicationService._();

  // Fetch all publications from API
  Future<List<Publication>> fetchPublications() async {
    print('📚 Fetching publications from API...');

    final urls = [
      'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublications',
      'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublications',
      // 'https://localhost:44342/umbraco/api/AppApi/GetPublications',
      // 'https://127.0.0.1:44342/umbraco/api/AppApi/GetPublications',
      // 'http://localhost:44342/umbraco/api/AppApi/GetPublications',
      // 'http://127.0.0.1:44342/umbraco/api/AppApi/GetPublications',
    ];

    for (String url in urls) {
      try {
        print('🌐 Trying API URL: $url');

        final response = await ApiClient.instance.get(url);

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();

          final List<dynamic> jsonList = jsonDecode(responseBody);

          final publications =
              jsonList.map((json) => Publication.fromJson(json)).toList();

          print(
              '📚 Successfully fetched ${publications.length} publications from $url');
          return publications;
        } else {
          print('❌ API error from $url: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error fetching from $url: $e');
        continue; // Try next URL
      }
    }

    // If all URLs failed
    print('❌ All API URLs failed');
    throw Exception('Failed to fetch publications from all API endpoints');
  }

  // Fetch publication content by ID with timeout
  Future<List<Chapter>> fetchPublicationContent(String publicationId) async {
    print('📖 Fetching content for publication: $publicationId');

    // Use production domain for content API
    final urls = [
      'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublicationsByPublicationId?publicationId=$publicationId',
      'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublicationsByPublicationId?publicationId=$publicationId',
    ];
    for (String url in urls) {
      try {
        print('🌐 Trying content URL: $url');

        final response = await ApiClient.instance.get(url);

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();

          final List<dynamic> jsonList = jsonDecode(responseBody);

          final chapters =
              jsonList.map((json) => Chapter.fromJson(json)).toList();

          print(
              '📖 Successfully fetched ${chapters.length} chapters from $url');
          return chapters;
        } else {
          print('❌ Content API error from $url: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error fetching content from $url: $e');
        continue; // Try next URL
      }
    }

    // If all URLs failed
    print('❌ All content API URLs failed');
    throw Exception(
        'Failed to fetch publication content from all API endpoints');
  }

  // Save publication content to local file
  Future<void> savePublicationContent(
      String publicationId, List<Chapter> chapters) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/publikasjon_$publicationId.json';
      final file = File(path);

      final jsonData = chapters.map((chapter) => chapter.toJson()).toList();
      final jsonString = jsonEncode(jsonData);

      await file.writeAsString(jsonString);

      print('💾 Publication content saved: $path');
    } catch (e) {
      print('❌ Error saving publication content: $e');
      throw Exception('Failed to save publication content: $e');
    }
  }

  // Load publication content from local file
  Future<List<Chapter>?> loadPublicationContent(String publicationId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/publikasjon_$publicationId.json';
      final file = File(path);

      if (!await file.exists()) {
        print('📖 No local content found for publication: $publicationId');
        return null;
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final chapters = jsonList.map((json) => Chapter.fromJson(json)).toList();

      print(
          '📖 Loaded ${chapters.length} chapters from local file for publication: $publicationId');
      return chapters;
    } catch (e) {
      print('❌ Error loading publication content: $e');
      return null;
    }
  }

  // Check if publication content exists locally
  Future<bool> hasLocalContent(String publicationId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/publikasjon_$publicationId.json';
      final file = File(path);

      return await file.exists();
    } catch (e) {
      print('❌ Error checking local content: $e');
      return false;
    }
  }

  // Download and save publication content
  Future<List<Chapter>> downloadPublicationContent(String publicationId) async {
    try {
      print('⬇️ Downloading content for publication: $publicationId');

      final chapters = await fetchPublicationContent(publicationId);
      await savePublicationContent(publicationId, chapters);

      print('✅ Successfully downloaded and saved publication: $publicationId');
      return chapters;
    } catch (e) {
      print('❌ Error downloading publication content: $e');
      throw Exception('Failed to download publication content: $e');
    }
  }

  // Download and save publication content with progress tracking
  Future<List<Chapter>> downloadPublicationContentWithProgress(
    String publicationId, {
    required Function(double progress, String status) onProgress,
    int? expectedSizeInBytes,
    Function()? isCancelled,
  }) async {
    try {
      print('🚀 === STARTING PUBLICATION DOWNLOAD ===');
      print('📦 Publication ID: $publicationId');
      print('📅 Download started at: ${DateTime.now()}');
      print(
          '⬇️ Downloading content with progress for publication: $publicationId');

      onProgress(0.0, 'Starter nedlasting...');
      await Future.delayed(const Duration(milliseconds: 200));

      // Check for cancellation early
      if (isCancelled?.call() == true) {
        print('🛑 Download cancelled by user at start');
        throw Exception('Download cancelled by user');
      }

      onProgress(0.1, 'Kobler til server...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Check for cancellation
      if (isCancelled?.call() == true) {
        print('🛑 Download cancelled by user while connecting');
        throw Exception('Download cancelled by user');
      }

      onProgress(0.2, 'Henter publikasjonsdata...');
      final chapters = await fetchPublicationContent(publicationId);
      print('📖 Downloaded ${chapters.length} chapters');

      // Check for cancellation after fetching
      if (isCancelled?.call() == true) {
        print('🛑 Download cancelled by user after fetching data');
        throw Exception('Download cancelled by user');
      }

      // Debug: Analyze content structure
      print('🔍 === ANALYZING DOWNLOADED CONTENT ===');
      int totalSubchapters = 0;
      for (final chapter in chapters) {
        totalSubchapters += chapter.subchapters.length;
        print(
            '📖 Chapter: ${chapter.title} (${chapter.subchapters.length} subchapters)');
      }
      print('📊 Total subchapters: $totalSubchapters');

      onProgress(0.5, 'Lagrer innhold...');
      await Future.delayed(const Duration(milliseconds: 200));

      // Check for cancellation before saving
      if (isCancelled?.call() == true) {
        print('🛑 Download cancelled by user before saving content');
        throw Exception('Download cancelled by user');
      }

      await savePublicationContent(publicationId, chapters);

      onProgress(0.6, '🖼️ Starter bildnedlasting...');
      await Future.delayed(
          const Duration(milliseconds: 500)); // Longer delay to see this stage

      // Check for cancellation before starting image download
      if (isCancelled?.call() == true) {
        print('🛑 Download cancelled by user before image download');
        // Delete saved content before throwing exception
        await _cleanupPartialDownload(publicationId);
        throw Exception('Download cancelled by user');
      }

      // Download images for offline use
      await downloadImagesForPublication(
        publicationId,
        isCancelled: isCancelled,
        onProgress: (double imageProgress, String imageStatus) {
          // Map image progress from 60% to 85% of total progress
          final totalProgress = 0.6 + (imageProgress * 0.25);
          final displayStatus = '🖼️ $imageStatus';
          onProgress(totalProgress, displayStatus);
          print(
              '🖼️ Image progress: ${(totalProgress * 100).toInt()}% - $displayStatus');
        },
      );

      // Check for cancellation before starting document download
      if (isCancelled?.call() == true) {
        print('🛑 Download cancelled by user before document download');
        await _cleanupPartialDownload(publicationId);
        throw Exception('Download cancelled by user');
      }

      onProgress(0.85, '📄 Starter dokumentnedlasting...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Download documents (PDF, XLS, etc.) for offline use
      await downloadDocumentsForPublication(
        publicationId,
        isCancelled: isCancelled,
        onProgress: (double docProgress, String docStatus) {
          // Map document progress from 85% to 95% of total progress
          final totalProgress = 0.85 + (docProgress * 0.10);
          final displayStatus = '📄 $docStatus';
          onProgress(totalProgress, displayStatus);
          print(
              '📄 Document progress: ${(totalProgress * 100).toInt()}% - $displayStatus');
        },
      );

      onProgress(1.0, '✅ Nedlasting fullført!');

      print(
          '✅ Successfully downloaded and saved publication with progress: $publicationId');
      return chapters;
    } catch (e) {
      print('❌ Error downloading publication content with progress: $e');
      // Clean up any partially downloaded data
      if (e.toString().contains('cancelled by user')) {
        print('🧹 Cleaning up cancelled download...');
        await _cleanupPartialDownload(publicationId);
      }
      throw Exception('Failed to download publication content: $e');
    }
  }

  // Clean up partially downloaded content when download is cancelled
  Future<void> _cleanupPartialDownload(String publicationId) async {
    try {
      print('🧹 === CLEANING UP PARTIAL DOWNLOAD ===');
      print('📦 Publication ID: $publicationId');

      final directory = await getApplicationDocumentsDirectory();

      // Delete main content JSON file
      final jsonPath = '${directory.path}/publikasjon_$publicationId.json';
      final jsonFile = File(jsonPath);
      if (await jsonFile.exists()) {
        await jsonFile.delete();
        print('🗑️ Deleted content JSON: $jsonPath');
      }

      // Delete all image files for this publication
      final allFiles = await directory.list().toList();
      int deletedImages = 0;
      for (final file in allFiles) {
        if (file is File) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          if (fileName.startsWith('content_img_${publicationId}_') &&
              fileName.endsWith('.img')) {
            await file.delete();
            deletedImages++;
            print('🗑️ Deleted image: $fileName');
          }
        }
      }

      print('✅ Cleanup completed: Deleted JSON and $deletedImages images');
    } catch (e) {
      print('❌ Error during cleanup: $e');
      // Don't throw - cleanup is best effort
    }
  }

  // Download images for a publication with progress tracking
  Future<void> downloadImagesForPublication(
    String publicationId, {
    required Function(double progress, String status) onProgress,
    Function()? isCancelled,
  }) async {
    try {
      print('🖼️ === STARTING IMAGE DOWNLOAD ===');
      print('📦 Publication ID: $publicationId');
      print('🖼️ Starting image download for publication: $publicationId');

      onProgress(0.0, 'Sjekker lagret innhold...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Load publication content using our model-based approach
      onProgress(0.1, 'Analyserer bilder i innhold...');
      await Future.delayed(const Duration(milliseconds: 300));

      print('🔍 === LOADING PUBLICATION CONTENT FOR IMAGE ANALYSIS ===');

      // Use our existing method to load chapters
      final chapters = await loadPublicationContent(publicationId);
      if (chapters == null) {
        throw Exception(
            'Kunne ikke laste publikasjonsinnhold for bildeanalyse.');
      }

      print('📊 Loaded ${chapters.length} chapters from saved content');

      // Extract all image URLs from the content using the correct structure
      final imageUrls = <String>{};
      int chapterCount = 0;

      for (final chapter in chapters) {
        chapterCount++;
        print('📖 Processing chapter $chapterCount: ${chapter.title}');
        print(
            '📄 Found ${chapter.subchapters.length} subchapters in this chapter');

        for (int i = 0; i < chapter.subchapters.length; i++) {
          final subchapter = chapter.subchapters[i];
          print('   📝 Subchapter ${i + 1}: ${subchapter.title}');

          final content = subchapter.text;
          final contentLength = content.length;
          print('   📜 Text content length: $contentLength chars');

          final urls = _extractImageUrlsFromHtml(content);
          if (urls.isNotEmpty) {
            print('   🖼️ Found ${urls.length} images in this subchapter:');
            for (final url in urls) {
              print('      📷 $url');
            }
          } else {
            print('   ℹ️ No images found in this subchapter');
          }
          imageUrls.addAll(urls);
        }
      }

      final totalImages = imageUrls.length;
      print('� === IMAGE EXTRACTION SUMMARY ===');
      print('🖼️ Total unique images found: $totalImages');
      if (totalImages > 0) {
        print('📷 Image URLs found:');
        final urlsList = imageUrls.toList();
        for (int i = 0; i < urlsList.length; i++) {
          print('   ${i + 1}. ${urlsList[i]}');
        }
      }
      print('�🖼️ Found $totalImages images to download');

      if (totalImages == 0) {
        print('⚠️ === NO IMAGES FOUND ===');
        print('❓ This could be because:');
        print('   1. The content has no image tags');
        print('   2. The JSON structure is different than expected');
        print('   3. Images are embedded differently in the HTML');
        onProgress(1.0, 'Ingen bilder funnet i innholdet');
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }

      onProgress(0.2, 'Fant $totalImages bilder å laste ned');
      await Future.delayed(const Duration(milliseconds: 500));

      int downloadedCount = 0;
      final urlsList = imageUrls.toList();

      print('🚀 === STARTING INDIVIDUAL IMAGE DOWNLOADS ===');

      for (int i = 0; i < urlsList.length; i++) {
        final imageUrl = urlsList[i];
        final progress = 0.2 + (i / urlsList.length) * 0.7;

        print('📥 === DOWNLOADING IMAGE ${i + 1}/$totalImages ===');
        print('🔗 URL: $imageUrl');
        onProgress(progress, 'Laster ned bilde ${i + 1} av $totalImages');

        // Check for cancellation before each image download
        if (isCancelled?.call() == true) {
          print('🛑 Image download cancelled by user');
          throw Exception('Download cancelled by user');
        }

        try {
          await _downloadAndCacheImageAsFile(
              imageUrl, publicationId, i, isCancelled);
          downloadedCount++;
          print('✅ Successfully downloaded image ${i + 1}');

          // Show progress for each downloaded image
          final downloadProgress = 0.2 + ((i + 1) / urlsList.length) * 0.7;
          onProgress(
              downloadProgress, 'Lastet ned bilde ${i + 1} av $totalImages');
        } catch (e) {
          print('❌ === IMAGE DOWNLOAD FAILED ===');
          print('🔗 URL: $imageUrl');
          print('💥 Error: $e');
          print('🔍 Error type: ${e.runtimeType}');
          onProgress(progress, 'Feil med bilde ${i + 1} - fortsetter...');
          // Continue with next image instead of failing completely
        }

        // Delay to make progress visible
        await Future.delayed(const Duration(milliseconds: 200));
      }

      print('📊 === IMAGE DOWNLOAD SUMMARY ===');
      print('✅ Successfully downloaded: $downloadedCount images');
      print('❌ Failed downloads: ${totalImages - downloadedCount} images');

      // Update JSON file to use local file references
      if (downloadedCount > 0) {
        print('🔄 Updating JSON file with local image paths...');
        onProgress(0.95, 'Oppdaterer bildelenker i JSON...');
        await _updateJsonWithLocalImagePaths(publicationId, urlsList);
      }

      onProgress(1.0, 'Bilder fullført ($downloadedCount/$totalImages)');
      print('✅ Image download completed: $downloadedCount/$totalImages images');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      print('❌ Error downloading images: $e');
      throw Exception('Feil ved nedlasting av bilder: $e');
    }
  }

  // Update JSON file to use local file paths instead of network URLs
  Future<void> _updateJsonWithLocalImagePaths(
      String publicationId, List<String> imageUrls) async {
    try {
      print('🔄 Updating JSON file with local image paths...');

      // Load the existing chapters using our loadPublicationContent method
      final chapters = await loadPublicationContent(publicationId);
      if (chapters == null) {
        print('❌ No chapters found for updating image paths');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();

      // Create mapping from original URL to local file path
      final urlToPathMapping = <String, String>{};
      for (int i = 0; i < imageUrls.length; i++) {
        final originalUrl = imageUrls[i];
        final localPath =
            'file://${directory.path}/content_img_${publicationId}_$i.img';

        // Map original URL
        urlToPathMapping[originalUrl] = localPath;

        // Also map localhost variations
        final localhostUrl = originalUrl.replaceAll(
            'nye.kompetansebiblioteket.no', 'nye.kompetansebiblioteket.no');
        urlToPathMapping[localhostUrl] = localPath;

        // Map without protocol variations
        final httpsUrl = originalUrl.replaceAll('http://', 'https://');
        final httpUrl = originalUrl.replaceAll('https://', 'http://');
        urlToPathMapping[httpsUrl] = localPath;
        urlToPathMapping[httpUrl] = localPath;

        // Also map relative URLs (starting with /)
        if (originalUrl.startsWith('/')) {
          final httpRelUrl = 'http://nye.kompetansebiblioteket.no$originalUrl';
          final httpsRelUrl =
              'https://nye.kompetansebiblioteket.no$originalUrl';
          final localhostHttpUrl =
              'http://nye.kompetansebiblioteket.no$originalUrl';
          final localhostHttpsUrl =
              'https://nye.kompetansebiblioteket.no$originalUrl';
          urlToPathMapping[httpRelUrl] = localPath;
          urlToPathMapping[httpsRelUrl] = localPath;
          urlToPathMapping[localhostHttpUrl] = localPath;
          urlToPathMapping[localhostHttpsUrl] = localPath;
        }

        print('📝 Mapping: $originalUrl -> $localPath');
      }

      // Update all subchapter text content with local file paths
      int updatesCount = 0;
      print(
          '🔍 Starting to update content with ${urlToPathMapping.length} URL mappings');

      final updatedChapters = <Chapter>[];

      for (final chapter in chapters) {
        final updatedSubchapters = <Subchapter>[];

        for (final subchapter in chapter.subchapters) {
          String updatedText = subchapter.text;
          final originalText = updatedText;

          // Replace all image URLs with local file paths
          urlToPathMapping.forEach((originalUrl, localPath) {
            if (updatedText.contains(originalUrl)) {
              updatedText = updatedText.replaceAll(originalUrl, localPath);
              updatesCount++;
              print(
                  '✅ Replaced "$originalUrl" with "$localPath" in "${subchapter.title}"');
            }
          });

          // Create new subchapter (always, to maintain immutability)
          final updatedSubchapter = Subchapter(
            title: subchapter.title,
            text: updatedText,
            number: subchapter.number,
          );

          updatedSubchapters.add(updatedSubchapter);

          if (updatedText != originalText) {
            print('📝 Content updated in subchapter: ${subchapter.title}');
          }
        }

        // Create new chapter with updated subchapters
        final updatedChapter = Chapter(
          title: chapter.title,
          subtitle: chapter.subtitle,
          number: chapter.number,
          abstract: chapter.abstract,
          subchapters: updatedSubchapters,
        );

        updatedChapters.add(updatedChapter);
      }

      // Save updated chapters back to file
      await savePublicationContent(publicationId, updatedChapters);

      print(
          '✅ Updated JSON file with $updatesCount local image path replacements');

      // Verify the update by reading the file again
      final verifyContent = await loadPublicationContent(publicationId);
      if (verifyContent != null) {
        int fileUrlCount = 0;
        for (final chapter in verifyContent) {
          for (final subchapter in chapter.subchapters) {
            fileUrlCount += 'file://'.allMatches(subchapter.text).length;
          }
        }
        print(
            '✅ Verification: JSON file now contains $fileUrlCount file:// references');

        // Show sample of updated content
        if (fileUrlCount > 0) {
          for (final chapter in verifyContent) {
            for (final subchapter in chapter.subchapters) {
              final firstFileMatch = subchapter.text.indexOf('file://');
              if (firstFileMatch != -1) {
                final start =
                    (firstFileMatch - 30).clamp(0, subchapter.text.length);
                final end =
                    (firstFileMatch + 80).clamp(0, subchapter.text.length);
                final sample = subchapter.text.substring(start, end);
                print('📝 Sample updated content: ...$sample...');
                return; // Show only first example
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error updating JSON with local image paths: $e');
    }
  }

  // Extract image URLs from HTML content
  List<String> _extractImageUrlsFromHtml(String htmlContent) {
    final imageUrls = <String>[];
    final imgRegex = RegExp(
        r'<img[^>]+src=["' "'" r']([^"' "'" r'>]+)["' "'" r'][^>]*>',
        caseSensitive: false);
    final matches = imgRegex.allMatches(htmlContent);

    print('🔍 === ANALYZING HTML CONTENT FOR IMAGES ===');
    print('📄 HTML content length: ${htmlContent.length} characters');
    print('🔍 Looking for img tags with regex...');
    print('📊 Found ${matches.length} img tag matches');

    if (matches.isEmpty && htmlContent.contains('<img')) {
      print('⚠️ HTML contains <img but no matches - checking content sample:');
      final imgIndex = htmlContent.indexOf('<img');
      if (imgIndex != -1) {
        final sample = htmlContent.substring(
            imgIndex, (imgIndex + 200).clamp(0, htmlContent.length));
        print('📄 Sample img tag: $sample');
      }
    }

    for (final match in matches) {
      final src = match.group(1);
      final fullMatch = match.group(0);
      print(
          '🔍 Found img tag: ${fullMatch?.substring(0, (fullMatch.length).clamp(0, 100))}...');
      print('🔗 Extracted src: $src');

      if (src != null &&
          src.isNotEmpty &&
          !src.startsWith('cached://') &&
          !src.startsWith('file://')) {
        // Fix localhost URLs for Android emulator
        final fixedUrl =
            src.replaceAll('localhost:44342', 'nye.kompetansebiblioteket.no');
        imageUrls.add(fixedUrl);
        print('✅ Added image URL: $fixedUrl');
      } else if (src != null && src.startsWith('cached://')) {
        print('⏭️ Skipping cached image: $src');
      } else if (src != null && src.startsWith('file://')) {
        print('⏭️ Skipping file image: $src');
      } else {
        print('❌ Invalid or empty src: $src');
      }
    }

    print('📊 === EXTRACTION SUMMARY ===');
    print('🖼️ Total extracted images: ${imageUrls.length}');
    return imageUrls;
  }

  // Extract document URLs (PDF, XLS, etc.) from HTML content
  List<String> _extractDocumentUrlsFromHtml(String htmlContent) {
    final documentUrls = <String>[];

    // Match <a> tags with href pointing to documents
    final linkRegex = RegExp(
      r'<a[^>]+href=["'
      "'"
      r']([^"'
      "'"
      r'>]+\.(pdf|xls|xlsx|doc|docx|ppt|pptx))["'
      "'"
      r'][^>]*>',
      caseSensitive: false,
    );

    print('🔍 === ANALYZING HTML CONTENT FOR DOCUMENTS ===');
    print('📄 HTML content length: ${htmlContent.length} characters');
    final matches = linkRegex.allMatches(htmlContent);
    print('📊 Found ${matches.length} document link matches');

    for (final match in matches) {
      final href = match.group(1);
      final extension = match.group(2);
      final fullMatch = match.group(0);
      print(
          '🔍 Found document link: ${fullMatch?.substring(0, (fullMatch.length).clamp(0, 100))}...');
      print('🔗 Extracted href: $href (.$extension)');

      if (href != null &&
          href.isNotEmpty &&
          !href.startsWith('file://') &&
          !href.startsWith('data:')) {
        // Fix localhost URLs for Android emulator
        final fixedUrl =
            href.replaceAll('localhost:44342', 'nye.kompetansebiblioteket.no');
        documentUrls.add(fixedUrl);
        print('✅ Added document URL: $fixedUrl');
      } else if (href != null && href.startsWith('file://')) {
        print('⏭️ Skipping file document: $href');
      } else {
        print('❌ Invalid or empty href: $href');
      }
    }

    print('📊 === DOCUMENT EXTRACTION SUMMARY ===');
    print('📄 Total extracted documents: ${documentUrls.length}');
    return documentUrls;
  }

  // Download documents for a publication
  Future<void> downloadDocumentsForPublication(
    String publicationId, {
    required Function(double progress, String status) onProgress,
    Function()? isCancelled,
  }) async {
    try {
      print('📄 === STARTING DOCUMENT DOWNLOAD ===');
      print('📦 Publication ID: $publicationId');

      onProgress(0.0, 'Sjekker lagret innhold...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Load publication content
      onProgress(0.1, 'Analyserer dokumenter i innhold...');
      await Future.delayed(const Duration(milliseconds: 300));

      final chapters = await loadPublicationContent(publicationId);
      if (chapters == null) {
        throw Exception(
            'Kunne ikke laste publikasjonsinnhold for dokumentanalyse.');
      }

      print('📊 Loaded ${chapters.length} chapters from saved content');

      // Extract all document URLs from the content
      final documentUrls = <String>{};
      for (final chapter in chapters) {
        for (final subchapter in chapter.subchapters) {
          final urls = _extractDocumentUrlsFromHtml(subchapter.text);
          documentUrls.addAll(urls);
        }
      }

      final totalDocuments = documentUrls.length;
      print('📄 === DOCUMENT EXTRACTION SUMMARY ===');
      print('📄 Total unique documents found: $totalDocuments');

      if (totalDocuments == 0) {
        print('⚠️ === NO DOCUMENTS FOUND ===');
        onProgress(1.0, 'Ingen dokumenter funnet i innholdet');
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }

      onProgress(0.2, 'Fant $totalDocuments dokumenter å laste ned');
      await Future.delayed(const Duration(milliseconds: 500));

      int downloadedCount = 0;
      final urlsList = documentUrls.toList();

      print('🚀 === STARTING INDIVIDUAL DOCUMENT DOWNLOADS ===');

      for (int i = 0; i < urlsList.length; i++) {
        final documentUrl = urlsList[i];
        final progress = 0.2 + (i / urlsList.length) * 0.7;

        print('📥 === DOWNLOADING DOCUMENT ${i + 1}/$totalDocuments ===');
        print('🔗 URL: $documentUrl');
        onProgress(progress, 'Laster ned dokument ${i + 1} av $totalDocuments');

        // Check for cancellation
        if (isCancelled?.call() == true) {
          print('🛑 Document download cancelled by user');
          throw Exception('Download cancelled by user');
        }

        try {
          await _downloadAndCacheDocumentAsFile(
              documentUrl, publicationId, i, isCancelled);
          downloadedCount++;
          print('✅ Successfully downloaded document ${i + 1}');

          final downloadProgress = 0.2 + ((i + 1) / urlsList.length) * 0.7;
          onProgress(downloadProgress,
              'Lastet ned dokument ${i + 1} av $totalDocuments');
        } catch (e) {
          print('❌ === DOCUMENT DOWNLOAD FAILED ===');
          print('🔗 URL: $documentUrl');
          print('💥 Error: $e');
          onProgress(progress, 'Feil med dokument ${i + 1} - fortsetter...');
          // Continue with next document
        }

        await Future.delayed(const Duration(milliseconds: 200));
      }

      print('📊 === DOCUMENT DOWNLOAD SUMMARY ===');
      print('✅ Successfully downloaded: $downloadedCount documents');
      print(
          '❌ Failed downloads: ${totalDocuments - downloadedCount} documents');

      // Update JSON file to use local file references
      if (downloadedCount > 0) {
        print('🔄 Updating JSON file with local document paths...');
        onProgress(0.95, 'Oppdaterer dokumentlenker i JSON...');
        await _updateJsonWithLocalDocumentPaths(publicationId, urlsList);
      }

      onProgress(1.0, 'Dokumenter fullført ($downloadedCount/$totalDocuments)');
      print(
          '✅ Document download completed: $downloadedCount/$totalDocuments documents');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      print('❌ Error downloading documents: $e');
      throw Exception('Feil ved nedlasting av dokumenter: $e');
    }
  }

  // Download and cache a single document as a file
  Future<void> _downloadAndCacheDocumentAsFile(
      String documentUrl, String publicationId, int index,
      [Function()? isCancelled]) async {
    try {
      print('📥 === DOWNLOADING DOCUMENT ===');
      print('🔗 URL: $documentUrl');
      print('📦 Publication: $publicationId');
      print('🔢 Index: $index');

      // Get file extension
      final uri = Uri.parse(documentUrl);
      final pathSegments = uri.pathSegments;
      final fileName = pathSegments.isNotEmpty ? pathSegments.last : '';
      final extension =
          fileName.contains('.') ? fileName.split('.').last : 'pdf';

      print('📄 File extension: $extension');

      // Build full URL
      String fullUrl = documentUrl;
      if (!documentUrl.startsWith('http')) {
        if (documentUrl.startsWith('/')) {
          fullUrl = 'https://nye.kompetansebiblioteket.no$documentUrl';
        } else {
          fullUrl = 'https://nye.kompetansebiblioteket.no/$documentUrl';
        }
      }

      print('🌐 Full URL: $fullUrl');

      // Check for cancellation before download
      if (isCancelled?.call() == true) {
        print('🛑 Document download cancelled before HTTP request');
        throw Exception('Download cancelled by user');
      }

      print('📞 Making HTTP request...');
      final response = await ApiClient.instance.get(fullUrl);

      print('📊 Response status: ${response.statusCode}');
      print('📏 Content length: ${response.contentLength}');

      if (response.statusCode == 200) {
        print('✅ HTTP response OK - reading bytes...');

        // Check for cancellation before reading response body
        if (isCancelled?.call() == true) {
          print('🛑 Document download cancelled before reading response');
          throw Exception('Download cancelled by user');
        }

        final bytes = await response.expand((chunk) => chunk).toList();

        print('📦 Downloaded ${bytes.length} bytes');

        if (bytes.isNotEmpty) {
          final filename = 'content_doc_${publicationId}_$index.$extension';
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$filename');

          print('💾 Saving to: ${file.path}');
          await file.writeAsBytes(bytes);

          // Verify file was written
          final savedFile = File(file.path);
          final fileExists = await savedFile.exists();
          final fileSize = fileExists ? await savedFile.length() : 0;

          print('✅ === DOCUMENT SAVE SUCCESSFUL ===');
          print('📁 File: $filename');
          print('📊 Size: ${bytes.length} bytes');
          print('✓ File exists: $fileExists');
          print('✓ File size on disk: $fileSize bytes');
        } else {
          throw Exception('Tomt dokumentinnhold');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error downloading document $index: $e');
      rethrow;
    }
  }

  // Update JSON file to use local document paths instead of network URLs
  Future<void> _updateJsonWithLocalDocumentPaths(
      String publicationId, List<String> documentUrls) async {
    try {
      print('🔄 Updating JSON file with local document paths...');

      final chapters = await loadPublicationContent(publicationId);
      if (chapters == null) {
        print('❌ No chapters found for updating document paths');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();

      // Create mapping from original URL to local file path
      final urlToPathMapping = <String, String>{};
      for (int i = 0; i < documentUrls.length; i++) {
        final originalUrl = documentUrls[i];

        // Get file extension
        final uri = Uri.parse(originalUrl);
        final pathSegments = uri.pathSegments;
        final fileName = pathSegments.isNotEmpty ? pathSegments.last : '';
        final extension =
            fileName.contains('.') ? fileName.split('.').last : 'pdf';

        final localPath =
            'file://${directory.path}/content_doc_${publicationId}_$i.$extension';

        urlToPathMapping[originalUrl] = localPath;

        // Also map URL variations
        final httpsUrl = originalUrl.replaceAll('http://', 'https://');
        final httpUrl = originalUrl.replaceAll('https://', 'http://');
        urlToPathMapping[httpsUrl] = localPath;
        urlToPathMapping[httpUrl] = localPath;

        print('📝 Mapping: $originalUrl -> $localPath');
      }

      // Update all subchapter text content with local file paths
      int updatesCount = 0;
      final updatedChapters = <Chapter>[];

      for (final chapter in chapters) {
        final updatedSubchapters = <Subchapter>[];

        for (final subchapter in chapter.subchapters) {
          String updatedText = subchapter.text;

          // Replace all document URLs with local file paths
          urlToPathMapping.forEach((originalUrl, localPath) {
            if (updatedText.contains(originalUrl)) {
              updatedText = updatedText.replaceAll(originalUrl, localPath);
              updatesCount++;
              print(
                  '✅ Replaced "$originalUrl" with "$localPath" in "${subchapter.title}"');
            }
          });

          final updatedSubchapter = Subchapter(
            title: subchapter.title,
            text: updatedText,
            number: subchapter.number,
          );

          updatedSubchapters.add(updatedSubchapter);
        }

        final updatedChapter = Chapter(
          title: chapter.title,
          subtitle: chapter.subtitle,
          number: chapter.number,
          abstract: chapter.abstract,
          subchapters: updatedSubchapters,
        );

        updatedChapters.add(updatedChapter);
      }

      // Save updated chapters back to file
      await savePublicationContent(publicationId, updatedChapters);

      print(
          '✅ Updated JSON file with $updatesCount local document path replacements');
    } catch (e) {
      print('❌ Error updating JSON with document paths: $e');
    }
  }

  // Get cached document file for offline viewing
  Future<File?> getCachedDocumentFile(
      String publicationId, int index, String extension) async {
    try {
      final filename = 'content_doc_${publicationId}_$index.$extension';
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');

      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('❌ Error getting cached document: $e');
    }

    return null;
  }

  // Download and cache a single image as a file (like old version)
  Future<void> _downloadAndCacheImageAsFile(
      String imageUrl, String publicationId, int index,
      [Function()? isCancelled]) async {
    try {
      print('🖼️ === DOWNLOADING SINGLE IMAGE ===');
      print('🔢 Image index: $index');
      print('🔗 Original URL: $imageUrl');

      // Fix localhost URLs for Android emulator
      final fixedUrl = imageUrl.replaceAll(
          'localhost:44342', 'nye.kompetansebiblioteket.no');
      // Ensure it's a full URL
      String fullUrl = fixedUrl.startsWith('http')
          ? fixedUrl
          : 'https://nye.kompetansebiblioteket.no$fixedUrl';

      // Add mobile optimization parameters
      final originalUri = Uri.parse(fullUrl);
      fullUrl = originalUri.toString();

      print('🔧 Fixed URL: $fixedUrl');
      print('📱 Optimized URL: $fullUrl');

      final uri = Uri.parse(fullUrl);
      print('🌐 Parsed URI: $uri');
      print('🏠 Host: ${uri.host}');
      print('🚪 Port: ${uri.port}');
      print('📁 Path: ${uri.path}');

      // Check for cancellation before making request
      if (isCancelled?.call() == true) {
        print('🛑 Image download cancelled before HTTP request');
        throw Exception('Download cancelled by user');
      }

      print('📞 Making HTTP request...');
      final response = await ApiClient.instance.get(fullUrl);

      print('📊 Response status: ${response.statusCode}');
      print('📏 Content length: ${response.contentLength}');

      if (response.statusCode == 200) {
        print('✅ HTTP response OK - reading bytes...');

        // Check for cancellation before reading response body
        if (isCancelled?.call() == true) {
          print('🛑 Image download cancelled before reading response');
          throw Exception('Download cancelled by user');
        }

        final bytes = await response.expand((chunk) => chunk).toList();

        print('📦 Downloaded ${bytes.length} bytes');

        if (bytes.isNotEmpty) {
          final filename = 'content_img_${publicationId}_$index.img';
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$filename');

          print('💾 Saving to: ${file.path}');
          await file.writeAsBytes(bytes);

          // Verify file was written
          final savedFile = File(file.path);
          final fileExists = await savedFile.exists();
          final fileSize = fileExists ? await savedFile.length() : 0;

          print('✅ === IMAGE SAVE SUCCESSFUL ===');
          print('📁 File: $filename');
          print('📊 Size: ${bytes.length} bytes');
          print('✓ File exists: $fileExists');
          print('✓ File size on disk: $fileSize bytes');
        } else {
          throw Exception('Tomt bildeinnhold');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error downloading image $index: $e');
      rethrow;
    }
  }

  // Get all locally downloaded publication IDs
  Future<List<String>> getDownloadedPublicationIds() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();

      final publicationIds = <String>[];

      for (final file in files) {
        if (file is File &&
            file.path.contains('publikasjon_') &&
            file.path.endsWith('.json')) {
          final fileName = file.uri.pathSegments.last;
          final match = RegExp(r'publikasjon_(.+)\.json').firstMatch(fileName);
          if (match != null) {
            publicationIds.add(match.group(1)!);
          }
        }
      }

      print('📚 Found ${publicationIds.length} downloaded publications');
      return publicationIds;
    } catch (e) {
      print('❌ Error getting downloaded publications: $e');
      return [];
    }
  }

  // Delete local publication content
  Future<void> deletePublicationContent(String publicationId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/publikasjon_$publicationId.json';
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted local content for publication: $publicationId');
      }
    } catch (e) {
      print('❌ Error deleting publication content: $e');
    }
  }

  // Clear all downloaded content
  Future<void> clearAllContent() async {
    try {
      final downloadedIds = await getDownloadedPublicationIds();

      for (final id in downloadedIds) {
        await deletePublicationContent(id);
      }

      print('🗑️ Cleared all downloaded content');
    } catch (e) {
      print('❌ Error clearing content: $e');
    }
  }

  // Get cached image file for offline viewing
  Future<File?> getCachedImageFile(String publicationId, int index) async {
    try {
      final filename = 'content_img_${publicationId}_$index.img';
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');

      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('❌ Error getting cached image: $e');
    }

    return null;
  }

  // Check if images are downloaded for a publication
  Future<bool> areImagesDownloaded(String publicationId) async {
    try {
      final filename = 'publikasjon_$publicationId.json';
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');

      if (!await file.exists()) {
        return false;
      }

      final jsonString = await file.readAsString();
      final content = jsonString;

      // Check if content contains cached:// references
      return content.contains('cached://');
    } catch (e) {
      print('❌ Error checking images: $e');
      return false;
    }
  }

  // Dispose method (no longer needed as we create HttpClient per request)
  void dispose() {
    // No cleanup needed
  }
}
