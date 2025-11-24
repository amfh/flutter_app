import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../models/new_publication.dart';
import '../models/user_data.dart';
import '../services/new_publication_service.dart';
import '../services/new_user_data_service.dart';
import '../services/local_storage_service.dart';

// Helper class to store table cell data with colspan/rowspan
class TableCellData {
  final String text;
  final String htmlContent; // Store original HTML
  final int colspan;
  final int rowspan;
  final TextAlign align;

  TableCellData({
    required this.text,
    required this.htmlContent,
    this.colspan = 1,
    this.rowspan = 1,
    this.align = TextAlign.left,
  });
}

class NewSubchapterDetailScreen extends StatefulWidget {
  final Publication publication;
  final Chapter chapter;
  final Subchapter subchapter;
  final List<Subchapter>? allSubchapters;
  final int? currentIndex;

  const NewSubchapterDetailScreen({
    super.key,
    required this.publication,
    required this.chapter,
    required this.subchapter,
    this.allSubchapters,
    this.currentIndex,
  });

  @override
  State<NewSubchapterDetailScreen> createState() =>
      _NewSubchapterDetailScreenState();
}

class _NewSubchapterDetailScreenState extends State<NewSubchapterDetailScreen> {
  String? _updatedContent;
  bool _isLoading = true;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _loadUpdatedContent();
    _checkIfBookmarked();
  }

  Future<void> _loadUpdatedContent() async {
    try {
      // Load the updated content from local storage that might have cached:// references
      final updatedSubchapter = await _getUpdatedSubchapterContent();

      setState(() {
        _updatedContent = updatedSubchapter?.text ?? widget.subchapter.text;
        _isLoading = false;
      });

      // Check if images need to be downloaded for this publication
      _checkAndDownloadImages();
    } catch (e) {
      // Error loading updated content
      setState(() {
        _updatedContent = widget.subchapter.text;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAndDownloadImages() async {
    try {
      print(
          '🖼️ Checking if images are available for publication ${widget.publication.id}');
      print(
          '💡 If images are missing, go to "Min side" to download offline content.');
    } catch (e) {
      print('❌ Error checking images: $e');
    }
  }

  Future<Subchapter?> _getUpdatedSubchapterContent() async {
    try {
      // Load the updated publication content from local storage
      final chapters = await NewPublicationService.instance
          .loadPublicationContent(widget.publication.id);

      if (chapters != null) {
        // Find the corresponding chapter and subchapter with updated content
        for (final chapter in chapters) {
          if (chapter.title == widget.chapter.title) {
            for (final subchapter in chapter.subchapters) {
              if (subchapter.title == widget.subchapter.title) {
                // Found updated subchapter content with cached images
                return subchapter;
              }
            }
          }
        }
      }

      // No updated content found, using original
      return null;
    } catch (e) {
      // Error getting updated subchapter content
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.subchapter.title),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subchapter.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.star : Icons.star_border,
              color: _isBookmarked ? Colors.yellow : Colors.white,
            ),
            onPressed: _toggleBookmark,
            tooltip: _isBookmarked ? 'Fjern bokmerke' : 'Legg til bokmerke',
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: _buildBody(context),
      bottomNavigationBar: _buildFloatingNavigationBar(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subchapter header (non-scrolling)
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: _buildHeader(),
        ),
        const SizedBox(height: 24),

        // Content (scrollable WebView takes remaining space)
        Expanded(
          child: _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.subchapter.number != null &&
            widget.subchapter.number!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Avsnitt ${widget.subchapter.number}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          widget.subchapter.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    // Use WebView to render HTML with processed MathJax
    return FutureBuilder<String>(
      future: _prepareHtmlWithImages(_updatedContent ?? widget.subchapter.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Forbereder innhold med bilder...'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Feil ved lasting av innhold: ${snapshot.error}'),
              ],
            ),
          );
        }
        return _buildWebViewContent(snapshot.data ?? '');
      },
    );
  }

  Future<String> _prepareHtmlWithImages(String htmlContent) async {
    print('🖼️ ========================================');
    print('🖼️ PREPARING HTML WITH CACHED IMAGES');
    print('🖼️ ========================================');
    print('🖼️ HTML content length: ${htmlContent.length} chars');

    // First, let's see what img tags exist in the HTML
    final allImgPattern = RegExp(r'<img[^>]*>', caseSensitive: false);
    final allImgs = allImgPattern.allMatches(htmlContent).toList();
    print('🖼️ Total img tags found in HTML: ${allImgs.length}');

    // Print first few img tags (with truncation for readability)
    for (var i = 0; i < allImgs.length && i < 3; i++) {
      final imgTag = allImgs[i].group(0) ?? '';
      final displayTag =
          imgTag.length > 200 ? '${imgTag.substring(0, 200)}...' : imgTag;
      print('🖼️ Img tag $i: $displayTag');
    }

    // Also check what's in the HTML around images
    final srcPattern =
        RegExp('src=["\']([^"\']{0,100})["\']', caseSensitive: false);
    final srcMatches = srcPattern.allMatches(htmlContent).toList();
    print('🖼️ Found ${srcMatches.length} src attributes in HTML');
    for (var i = 0; i < srcMatches.length && i < 5; i++) {
      final src = srcMatches[i].group(1) ?? '';
      print('🖼️ Src $i: $src');
    }

    String processedHtml = htmlContent;
    int successCount = 0;
    int failCount = 0;

    // Pattern 1: cached:// URLs (format: cached://publicationId/imageIndex)
    final cachedPattern = RegExp(
      '<img([^>]*)src=["\']cached://([^/]+)/(\\d+)["\']([^>]*)>',
      caseSensitive: false,
    );

    // Pattern 2: file:// URLs (format: file:///path/to/image)
    final filePattern = RegExp(
      '<img([^>]*)src=["\']file://([^"\']+)["\']([^>]*)>',
      caseSensitive: false,
    );

    // Pattern 3: Relative paths (e.g., /media/hvljumra/image.png)
    final relativePattern = RegExp(
      '<img([^>]*)src=["\'](/[^"\']+)["\']([^>]*)>',
      caseSensitive: false,
    );

    final cachedMatches = cachedPattern.allMatches(htmlContent).toList();
    final fileMatches = filePattern.allMatches(htmlContent).toList();
    final relativeMatches = relativePattern.allMatches(htmlContent).toList();

    print('🖼️ Found ${cachedMatches.length} img tags with cached:// URLs');
    print('🖼️ Found ${fileMatches.length} img tags with file:// URLs');
    print('🖼️ Found ${relativeMatches.length} img tags with relative paths');

    // Process cached:// URLs
    for (final match in cachedMatches) {
      final beforeSrc = match.group(1) ?? '';
      final publicationId = match.group(2);
      final imageIndex = match.group(3);
      final afterSrc = match.group(4) ?? '';

      print('🖼️ ----------------------------------------');
      print('🖼️ Processing cached:// image:');
      print('🖼️   Publication ID: $publicationId');
      print('🖼️   Image Index: $imageIndex');

      try {
        final filename = 'content_img_${publicationId}_$imageIndex.img';
        print('🖼️   Looking for file: $filename');

        final imageFile = await LocalStorageService.readImageFile(filename);

        if (imageFile != null && await imageFile.exists()) {
          final fileSize = await imageFile.length();
          print('✅   FOUND cached image: ${imageFile.path}');
          print('✅   File size: $fileSize bytes');

          final imageBytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(imageBytes);

          String mimeType = 'image/jpeg';
          if (imageBytes.length >= 2) {
            if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50) {
              mimeType = 'image/png';
            } else if (imageBytes[0] == 0x47 && imageBytes[1] == 0x49) {
              mimeType = 'image/gif';
            } else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
              mimeType = 'image/jpeg';
            } else if (imageBytes[0] == 0x52 && imageBytes[1] == 0x49) {
              mimeType = 'image/webp';
            }
          }

          print('✅   Detected MIME type: $mimeType');

          final dataUrl = 'data:$mimeType;base64,$base64Image';
          final originalTag = match.group(0)!;
          final newTag = '<img${beforeSrc}src="$dataUrl"$afterSrc>';
          processedHtml = processedHtml.replaceFirst(originalTag, newTag);

          print('✅   Successfully replaced with base64 data URL');
          successCount++;
        } else {
          print('❌   Cached image NOT FOUND: $filename');
          failCount++;
        }
      } catch (e) {
        print('❌   ERROR processing cached:// image:');
        print('❌   Error: $e');
        failCount++;
      }
    }

    // Process file:// URLs
    for (final match in fileMatches) {
      final beforeSrc = match.group(1) ?? '';
      final filePath = match.group(2) ?? '';
      final afterSrc = match.group(3) ?? '';

      print('🖼️ ----------------------------------------');
      print('🖼️ Processing file:// image:');
      print('🖼️   File path: $filePath');

      try {
        // Use the ACTUAL file path from the file:// URL
        // filePath is like: /data/user/0/com.example.flutter_app/app_flutter/content_img_...img
        final imageFile = File(filePath);

        print('🖼️   Checking file at: ${imageFile.path}');

        if (await imageFile.exists()) {
          final fileSize = await imageFile.length();
          print('✅   FOUND file:// image: ${imageFile.path}');
          print('✅   File size: $fileSize bytes');

          final imageBytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(imageBytes);

          String mimeType = 'image/jpeg';
          if (imageBytes.length >= 2) {
            if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50) {
              mimeType = 'image/png';
            } else if (imageBytes[0] == 0x47 && imageBytes[1] == 0x49) {
              mimeType = 'image/gif';
            } else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
              mimeType = 'image/jpeg';
            } else if (imageBytes[0] == 0x52 && imageBytes[1] == 0x49) {
              mimeType = 'image/webp';
            }
          }

          print('✅   Detected MIME type: $mimeType');

          final dataUrl = 'data:$mimeType;base64,$base64Image';
          final originalTag = match.group(0)!;
          final newTag = '<img${beforeSrc}src="$dataUrl"$afterSrc>';
          processedHtml = processedHtml.replaceFirst(originalTag, newTag);

          print('✅   Successfully replaced file:// with base64 data URL');
          successCount++;
        } else {
          print('❌   File:// image NOT FOUND at path: ${imageFile.path}');

          // Add placeholder
          final originalTag = match.group(0)!;
          final placeholderSvg =
              '''<svg width="100%" height="200" xmlns="http://www.w3.org/2000/svg">
            <rect width="100%" height="100%" fill="#FFF3CD" stroke="#856404" stroke-width="2"/>
            <text x="50%" y="40%" text-anchor="middle" fill="#856404" font-size="16" font-weight="bold">
              ⚠️ Bilde ikke funnet
            </text>
            <text x="50%" y="55%" text-anchor="middle" fill="#856404" font-size="14">
              Filsti: ${filePath.length > 40 ? '...${filePath.substring(filePath.length - 40)}' : filePath}
            </text>
          </svg>''';
          final placeholderDataUrl =
              'data:image/svg+xml;base64,${base64Encode(utf8.encode(placeholderSvg))}';
          final newTag = '<img${beforeSrc}src="$placeholderDataUrl"$afterSrc>';
          processedHtml = processedHtml.replaceFirst(originalTag, newTag);

          failCount++;
        }
      } catch (e) {
        print('❌   ERROR processing file:// image:');
        print('❌   Error: $e');
        failCount++;
      }
    }

    // Process relative paths (e.g., /media/hvljumra/image.png)
    for (final match in relativeMatches) {
      final beforeSrc = match.group(1) ?? '';
      final relativePath = match.group(2) ?? '';
      final afterSrc = match.group(3) ?? '';

      print('🖼️ ----------------------------------------');
      print('🖼️ Processing relative path image:');
      print('🖼️   Relative path: $relativePath');

      try {
        // Extract filename from path
        final fileName = relativePath.split('/').last;
        print('🖼️   Extracted filename: $fileName');

        // Search in media directory
        final directory = await getApplicationDocumentsDirectory();
        final mediaDir =
            Directory('${directory.path}/${widget.publication.id}_media');

        print('🖼️   Looking in media directory: ${mediaDir.path}');

        if (await mediaDir.exists()) {
          final imageFile = File('${mediaDir.path}/$fileName');

          if (await imageFile.exists()) {
            final fileSize = await imageFile.length();
            print('✅   FOUND relative path image: ${imageFile.path}');
            print('✅   File size: $fileSize bytes');

            final imageBytes = await imageFile.readAsBytes();
            final base64Image = base64Encode(imageBytes);

            String mimeType = 'image/jpeg';
            if (imageBytes.length >= 2) {
              if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50) {
                mimeType = 'image/png';
              } else if (imageBytes[0] == 0x47 && imageBytes[1] == 0x49) {
                mimeType = 'image/gif';
              } else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
                mimeType = 'image/jpeg';
              } else if (imageBytes[0] == 0x52 && imageBytes[1] == 0x49) {
                mimeType = 'image/webp';
              }
            }

            print('✅   Detected MIME type: $mimeType');

            final dataUrl = 'data:$mimeType;base64,$base64Image';
            final originalTag = match.group(0)!;
            final newTag = '<img${beforeSrc}src="$dataUrl"$afterSrc>';
            processedHtml = processedHtml.replaceFirst(originalTag, newTag);

            print(
                '✅   Successfully replaced relative path with base64 data URL');
            successCount++;
          } else {
            print(
                '❌   Relative path image NOT FOUND: $fileName in ${mediaDir.path}');

            // Try case-insensitive search
            final allFiles = await mediaDir.list().toList();
            bool foundCaseInsensitive = false;

            for (final file in allFiles) {
              if (file is File) {
                final existingFileName =
                    file.path.split(Platform.pathSeparator).last;
                if (existingFileName.toLowerCase() == fileName.toLowerCase()) {
                  print('✅   Found case-insensitive match: ${file.path}');

                  final imageBytes = await file.readAsBytes();
                  final base64Image = base64Encode(imageBytes);

                  String mimeType = 'image/jpeg';
                  if (imageBytes.length >= 2) {
                    if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50) {
                      mimeType = 'image/png';
                    } else if (imageBytes[0] == 0x47 && imageBytes[1] == 0x49) {
                      mimeType = 'image/gif';
                    } else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
                      mimeType = 'image/jpeg';
                    } else if (imageBytes[0] == 0x52 && imageBytes[1] == 0x49) {
                      mimeType = 'image/webp';
                    }
                  }

                  final dataUrl = 'data:$mimeType;base64,$base64Image';
                  final originalTag = match.group(0)!;
                  final newTag = '<img${beforeSrc}src="$dataUrl"$afterSrc>';
                  processedHtml =
                      processedHtml.replaceFirst(originalTag, newTag);

                  print('✅   Successfully replaced with base64 data URL');
                  successCount++;
                  foundCaseInsensitive = true;
                  break;
                }
              }
            }

            if (!foundCaseInsensitive) {
              print('❌   No matching file found');
              failCount++;
            }
          }
        } else {
          print('❌   Media directory does not exist: ${mediaDir.path}');
          failCount++;
        }
      } catch (e) {
        print('❌   ERROR processing relative path image:');
        print('❌   Error: $e');
        failCount++;
      }
    }

    print('🖼️ ========================================');
    print('🖼️ HTML PREPARATION COMPLETE');
    print('🖼️ Success: $successCount images');
    print('🖼️ Failed: $failCount images');
    print('🖼️ Processed HTML length: ${processedHtml.length} chars');

    // Fix relative links by converting them to absolute URLs
    // Pattern: href="/media/..." or href="/something..."
    print('🔗 Converting relative links to absolute URLs...');
    final baseUrl = 'https://nye.kompetansebiblioteket.no';

    processedHtml = processedHtml.replaceAllMapped(
      RegExp(r'href="(/[^"]*)"', caseSensitive: false),
      (match) {
        final relativePath = match.group(1) ?? '';
        final absoluteUrl = '$baseUrl$relativePath';
        print('🔗   Converting: $relativePath -> $absoluteUrl');
        return 'href="$absoluteUrl"';
      },
    );

    // Debug: Check for links in HTML after conversion
    final linkPattern = RegExp(r'<a\s+[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        caseSensitive: false, dotAll: true);
    final linkMatches = linkPattern.allMatches(processedHtml);
    print('🔗 Found ${linkMatches.length} links in HTML after conversion:');
    for (final match in linkMatches.take(5)) {
      // Show first 5 links
      print('🔗   href="${match.group(1)}" text="${match.group(2)?.trim()}"');
    }

    // Debug: Print a sample of processed HTML if images were found
    if (successCount > 0 || failCount > 0) {
      final sampleLength =
          processedHtml.length > 500 ? 500 : processedHtml.length;
      print('🖼️ Sample of processed HTML (first $sampleLength chars):');
      print(processedHtml.substring(0, sampleLength));
    }

    print('🖼️ ========================================');

    return processedHtml;
  }

  Widget _buildWebViewContent(String htmlContent) {
    // Fix brackets in table cells while preserving MathJax in formulas
    String processedHtml = htmlContent;

    // First: Fix brackets within td/th tags (table cells) - simple text brackets
    // This handles cases like [ m / s ] or [ kg / m 3 ] in tables
    processedHtml = processedHtml.replaceAllMapped(
        RegExp(r'(<t[dh][^>]*>)(.*?)(</t[dh]>)', dotAll: true), (match) {
      String openTag = match.group(1) ?? '';
      String cellContent = match.group(2) ?? '';
      String closeTag = match.group(3) ?? '';

      // Within table cells, replace brackets with non-breaking version
      cellContent = cellContent.replaceAllMapped(
          RegExp(r'\[([^\]]{1,50}?)\]', dotAll: true), (bracketMatch) {
        String content = bracketMatch.group(1) ?? '';
        // Only process if it doesn't contain complex MathJax (has span/div tags)
        if (!content.contains('<span') && !content.contains('<div')) {
          // Remove simple HTML tags
          content = content.replaceAll(RegExp(r'<[^>]+>'), '');
          // Replace all whitespace with non-breaking spaces
          content = content.replaceAll(RegExp(r'\s+'), '&nbsp;');
          return '<nobr>[$content]</nobr>';
        }
        return bracketMatch.group(0) ?? '';
      });

      return '$openTag$cellContent$closeTag';
    });

    // Second: Fix simple brackets outside tables (like in paragraphs)
    // but skip those that are already wrapped in nobr or contain MathJax
    processedHtml = processedHtml.replaceAllMapped(
        RegExp(r'(?<!<nobr>)\[([^\]]{1,50}?)\](?!</nobr>)', dotAll: true),
        (match) {
      String fullMatch = match.group(0) ?? '';
      String content = match.group(1) ?? '';

      // Skip if this looks like it's part of MathJax (contains span/div tags)
      if (content.contains('<span') || content.contains('<div')) {
        return fullMatch;
      }

      // Check if already processed (inside nobr)
      if (fullMatch.contains('nobr')) {
        return fullMatch;
      }

      // Process simple brackets
      content = content.replaceAll(RegExp(r'<[^>]+>'), '');
      content = content.replaceAll(RegExp(r'\s+'), '&nbsp;');
      return '<nobr>[$content]</nobr>';
    });

    // Wrap content in a complete HTML document with proper styling
    final wrappedHtml = '''
<!DOCTYPE html>
<html style="height: auto; min-height: 100%;">
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        * {
            box-sizing: border-box;
        }
        
        html, body {
            height: auto;
            min-height: 100%;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            font-size: 16px;
            line-height: 1.6;
            color: #333;
            padding: 16px;
            padding-bottom: 100px;
            margin: 0;
            background-color: white;
            overflow-x: hidden;
            max-width: 100%;
        }
        
        /* Wrapper for tables to enable horizontal scrolling */
        table {
            border-collapse: collapse;
            margin: 16px 0;
            width: 100% !important;
            display: block;
            overflow-x: auto;
            max-width: 100%;
            border: none !important;
        }
        
        td, th {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
            vertical-align: top;
        }
        
        /* Only apply nowrap to small content cells, not wrapper cells */
        td:not(.BlueTextBoxWrapper):not(.WhiteTextBoxWrapper):not(.BlueTextBoxWrapperContent):not(.WhiteTextBoxWrapperContent),
        th:not(.BlueTextBoxWrapper):not(.WhiteTextBoxWrapper):not(.BlueTextBoxWrapperContent):not(.WhiteTextBoxWrapperContent) {
            white-space: nowrap;
        }
        
        /* Wrapper cells should allow text wrapping */
        td.BlueTextBoxWrapper,
        td.WhiteTextBoxWrapper,
        td.BlueTextBoxWrapperContent,
        td.WhiteTextBoxWrapperContent {
            white-space: normal;
            word-wrap: break-word;
        }
        
        th {
            background-color: #f5f5f5;
            font-weight: bold;
        }
        
        a {
            color: #0974ba;
            text-decoration: none;
        }
        
        a:hover {
            text-decoration: underline;
        }
        
        /* MathJax display styles - keep existing MathJax formatting */
        .MathJax_Display {
            text-align: center;
            margin: 1em 0;
            overflow-x: auto;
        }
        
        .MathJax {
            display: inline-block !important;
            white-space: nowrap !important;
        }
        
        .MathJax * {
            white-space: nowrap !important;
        }
        
        /* Ensure MathJax spans stay inline */
        .math {
            display: inline-block !important;
            white-space: nowrap !important;
        }
        
        /* MathJax text elements */
        .mtext {
            white-space: nowrap !important;
            display: inline !important;
        }
        
        /* All MathJax span elements */
        span.MathJax,
        span.math,
        span.mrow,
        span.mstyle,
        span.msub,
        span.mi,
        span.mo,
        span.mtext {
            display: inline-block !important;
            white-space: nowrap !important;
        }
        
        /* nobr elements should have normal font size and not be subscript */
        nobr {
            font-size: inherit !important;
            vertical-align: baseline !important;
            display: inline !important;
            white-space: nowrap !important;
        }
        
        /* Blue box wrapper */
        td.BlueTextBoxWrapper {
            background-color: #E3F2FD !important;
            border: 2px solid #0974ba !important;
            border-radius: 8px;
            padding: 0 !important;
            margin: 16px 0;
            max-width: 100%;
            box-sizing: border-box;
        }
        
        /* White box wrapper */
        td.WhiteTextBoxWrapper {
            background-color: white !important;
            border: 2px solid #ccc !important;
            border-radius: 8px;
            padding: 0 !important;
            margin: 16px 0;
            max-width: 100%;
            box-sizing: border-box;
        }
        
        /* Handle nested tables in content boxes */
        .BlueTextBoxWrapper table,
        .WhiteTextBoxWrapper table,
        .BlueTextBoxWrapperContent table,
        .WhiteTextBoxWrapperContent table {
            border: none;
            margin: 0;
            width: 100%;
            max-width: 100%;
            table-layout: auto;
        }
        
        .BlueTextBoxWrapper td,
        .WhiteTextBoxWrapper td,
        .BlueTextBoxWrapperContent td,
        .WhiteTextBoxWrapperContent td {
            border: none;
            white-space: normal !important;
            word-wrap: break-word;
            overflow-wrap: break-word;
            padding: 0;
        }
        
        /* Add padding to the inner content cell */
        td.BlueTextBoxWrapperContent,
        td.WhiteTextBoxWrapperContent {
            padding: 16px !important;
        }
        
        /* Images */
        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 8px 0;
        }
        
        /* Headings */
        h1, h2, h3, h4, h5, h6 {
            color: #0974ba;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
        }
        
        /* Paragraphs */
        p {
            margin: 0.5em 0;
        }
        
        /* Lists */
        ul, ol {
            padding-left: 20px;
            margin: 0.5em 0;
        }
        
        li {
            margin: 0.25em 0;
        }
        
        /* Prevent text selection issues */
        .math {
            user-select: none;
            -webkit-user-select: none;
        }
        
        /* Handle formula numbers in MathJax */
        .mtext[style*="dodgerblue"] {
            color: #0974ba !important;
        }
    </style>
    <script>
        // Send height to Flutter when content loads
        window.addEventListener('load', function() {
            const height = document.body.scrollHeight;
            console.log('Content height: ' + height);
        });
        
        // Handle dynamic content changes
        const observer = new MutationObserver(function() {
            const height = document.body.scrollHeight;
            console.log('Content height changed: ' + height);
        });
        observer.observe(document.body, { childList: true, subtree: true });
    </script>
</head>
<body>
    $processedHtml
</body>
</html>
''';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            print('🔗 Navigation request: ${request.url}');
            print(
                '🔍 URL starts with http: ${request.url.startsWith('http://')}');
            print(
                '🔍 URL starts with https: ${request.url.startsWith('https://')}');

            // Handle external links and downloadable files
            if (request.url.startsWith('http://') ||
                request.url.startsWith('https://')) {
              // Check if this is a downloadable file (PDF, XLS, DOC, etc.)
              final uri = Uri.parse(request.url);
              final path = uri.path.toLowerCase();
              final isDownloadableFile = path.endsWith('.pdf') ||
                  path.endsWith('.xls') ||
                  path.endsWith('.xlsx') ||
                  path.endsWith('.doc') ||
                  path.endsWith('.docx') ||
                  path.endsWith('.ppt') ||
                  path.endsWith('.pptx') ||
                  path.endsWith('.zip') ||
                  path.endsWith('.rar');

              if (isDownloadableFile) {
                print('📄 Detected downloadable file: ${request.url}');
                // Start async operation to check and open file
                _handleDownloadableFileAsync(request.url, context);
                // Always prevent navigation for downloadable files
                return NavigationDecision.prevent;
              } else {
                print('🔗 Opening external link: ${request.url}');
                _launchUrl(request.url);
                return NavigationDecision.prevent;
              }
            }

            // Handle local file links
            if (request.url.startsWith('file://')) {
              print('📄 Opening local file: ${request.url}');
              _openLocalDocument(request.url, context);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            print('📄 WebView page loaded');
          },
        ),
      )
      ..loadHtmlString(wrappedHtml);

    // Return WebView that fills available space
    // The WebView will handle its own scrolling
    return WebViewWidget(controller: controller);
  }

  Future<void> _launchUrl(String url) async {
    // Show dialog to let user choose how to open the URL
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.open_in_browser, color: Color(0xFF0974ba), size: 28),
            SizedBox(width: 8),
            Text('Åpne ekstern lenke'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Denne lenken åpner en ekstern nettside:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF0974ba).withOpacity(0.3),
                ),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0974ba),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vil du åpne denne lenken i nettleseren?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Avbryt'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Åpne'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0974ba),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      final uri = Uri.parse(url);
      try {
        // Try to launch the URL with different modes
        bool launched = false;

        // First try: externalApplication (opens in browser)
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          print('⚠️ externalApplication failed: $e');
        }

        // Second try: platformDefault (let OS decide)
        if (!launched) {
          try {
            launched = await launchUrl(
              uri,
              mode: LaunchMode.platformDefault,
            );
          } catch (e) {
            print('⚠️ platformDefault failed: $e');
          }
        }

        // Third try: externalNonBrowserApplication (for apps like YouTube)
        if (!launched) {
          try {
            launched = await launchUrl(
              uri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
          } catch (e) {
            print('⚠️ externalNonBrowserApplication failed: $e');
          }
        }

        if (launched) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Åpner lenke i nettleser...'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('LaunchUrl returnerte false');
        }
      } catch (e) {
        print('❌ Could not launch $url: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kunne ikke åpne lenken: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // Build content with custom table parsing
  Widget _buildContentWithTables(String htmlContent, BuildContext context) {
    List<Widget> widgets = [];

    // 1. Vimeo embed detection and replacement
    var vimeoPattern = RegExp(
        '<a href=["\'](https://vimeo.com/\\d+)["\'][^>]*>(.*?)</a>',
        caseSensitive: false);
    var vimeoMatches = vimeoPattern.allMatches(htmlContent).toList();

    print('🎥 DEBUG: Checking for Vimeo links in content...');
    print('🎥 DEBUG: Found ${vimeoMatches.length} Vimeo links');

    for (final match in vimeoMatches) {
      final vimeoUrl = match.group(1);
      final linkText = match.group(2);
      print('🎥 DEBUG: Vimeo URL: $vimeoUrl, Text: $linkText');
    }
    int lastIndex = 0;

    for (final match in vimeoMatches) {
      // Add HTML content before Vimeo link
      if (match.start > lastIndex) {
        final beforeContent = htmlContent.substring(lastIndex, match.start);
        if (beforeContent.trim().isNotEmpty) {
          widgets.add(Html(
            data: beforeContent,
            style: _getHtmlStyle(),
            onLinkTap: (url, attributes, element) {
              _handleLinkTap(url, context);
            },
          ));
        }
      }

      // Extract Vimeo video ID and create embed player
      final vimeoUrl = match.group(1);
      if (vimeoUrl != null) {
        final videoId = vimeoUrl.split('/').last;
        final embedUrl = 'https://player.vimeo.com/video/$videoId';
        widgets.add(VimeoWebView(embedUrl: embedUrl));
      }

      lastIndex = match.end;
    }

    // Add remaining HTML after last Vimeo link
    if (lastIndex < htmlContent.length) {
      final afterContent = htmlContent.substring(lastIndex);
      if (afterContent.trim().isNotEmpty) {
        // Continue with image/table parsing for remaining content
        widgets.add(_buildContentWithImagesAndTables(afterContent, context));
      }
    }

    // If no Vimeo found, fallback to normal parsing
    if (widgets.isEmpty) {
      widgets.add(_buildContentWithImagesAndTables(htmlContent, context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Helper: Build content with images and tables (original logic)
  Widget _buildContentWithImagesAndTables(
      String htmlContent, BuildContext context) {
    List<Widget> widgets = [];

    print('📊 DEBUG: Processing content for tables and images...');
    print('📊 DEBUG: Content length: ${htmlContent.length}');
    print('📊 DEBUG: Contains <table>: ${htmlContent.contains('<table')}');

    // First, parse tables in the content
    final tablePattern =
        RegExp(r'<table[^>]*>.*?</table>', caseSensitive: false, dotAll: true);
    final tableMatches = tablePattern.allMatches(htmlContent).toList();
    print('📊 DEBUG: Found ${tableMatches.length} table(s)');

    int tableLastIndex = 0;

    for (final match in tablePattern.allMatches(htmlContent)) {
      // Add HTML content before this table
      if (match.start > tableLastIndex) {
        final beforeContent =
            htmlContent.substring(tableLastIndex, match.start);
        if (beforeContent.trim().isNotEmpty) {
          // Process the content before table for images
          widgets.addAll(_buildContentWithImages(beforeContent, context));
        }
      }

      // Add the table widget
      final tableHtml = match.group(0);
      if (tableHtml != null) {
        widgets.add(_buildExtractedTable(tableHtml));
      }

      tableLastIndex = match.end;
    }

    // Add remaining HTML content after the last table
    if (tableLastIndex < htmlContent.length) {
      final afterContent = htmlContent.substring(tableLastIndex);
      if (afterContent.trim().isNotEmpty) {
        widgets.addAll(_buildContentWithImages(afterContent, context));
      }
    }

    // If no tables found, process for images only
    if (widgets.isEmpty) {
      widgets.addAll(_buildContentWithImages(htmlContent, context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Helper: Build content with images only
  List<Widget> _buildContentWithImages(
      String htmlContent, BuildContext context) {
    // Check for images
    if (htmlContent.contains('<img')) {
      print('🔍 DEBUG: Found <img> tags in content, using image-aware parsing');

      final contentWidgets =
          _buildContentSegmentWithImages(htmlContent, context);

      return contentWidgets;
    }

    // No images, just return HTML content
    return [
      Html(
        data: htmlContent,
        style: _getHtmlStyle(),
        onLinkTap: (url, attributes, element) {
          _handleLinkTap(url, context);
        },
      )
    ];
  }

  // Build content segment with proper image handling
  List<Widget> _buildContentSegmentWithImages(
      String htmlContent, BuildContext context) {
    List<Widget> widgets = [];

    // Split content by image tags - use string-based approach
    final imgPattern = RegExp(r'<img[^>]+src=(["\047])([^"\047]+)\1[^>]*>',
        caseSensitive: false, dotAll: true);
    int lastIndex = 0;

    print(
        '🔍 _buildContentSegmentWithImages: Processing content length: ${htmlContent.length}');
    final matches = imgPattern.allMatches(htmlContent).toList();
    print('🔍 Found ${matches.length} image matches');

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final src = match.group(2);
      print('📷 Match $i: src="$src"');
    }

    for (final match in imgPattern.allMatches(htmlContent)) {
      // Add HTML content before this image
      if (match.start > lastIndex) {
        final beforeContent = htmlContent.substring(lastIndex, match.start);
        if (beforeContent.trim().isNotEmpty) {
          widgets.add(Html(
            data: beforeContent,
            style: _getHtmlStyle(),
            onLinkTap: (url, attributes, element) {
              _handleLinkTap(url, context);
            },
          ));
        }
      }

      // Add the image widget
      final src = match.group(2); // Extract src attribute
      if (src != null) {
        widgets.add(_buildImageWidget(src));
      }

      lastIndex = match.end;
    }

    // Add remaining HTML content after the last image
    if (lastIndex < htmlContent.length) {
      final remainingContent = htmlContent.substring(lastIndex);
      if (remainingContent.trim().isNotEmpty) {
        widgets.add(Html(
          data: remainingContent,
          style: _getHtmlStyle(),
          onLinkTap: (url, attributes, element) {
            _handleLinkTap(url, context);
          },
        ));
      }
    }

    return widgets;
  }

  // Build content box (for BlueTextBoxWrapper and WhiteTextBoxWrapper nested tables)
  Widget _buildContentBox(String tableHtml) {
    // Determine which type of box this is
    final isBlueBox = tableHtml.contains('BlueTextBoxWrapper');

    // Extract the inner content from nested table structure
    // Try BlueTextBoxWrapperContent first, then WhiteTextBoxWrapperContent
    RegExpMatch? contentMatch = RegExp(
      r'<td[^>]*class="BlueTextBoxWrapperContent"[^>]*>(.*?)</td>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(tableHtml);

    contentMatch ??= RegExp(
      r'<td[^>]*class="WhiteTextBoxWrapperContent"[^>]*>(.*?)</td>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(tableHtml);

    if (contentMatch != null) {
      final content = contentMatch.group(1) ?? '';

      // Define colors based on box type
      final backgroundColor = isBlueBox
          ? const Color(0xFFE3F2FD) // Light blue for BlueTextBoxWrapper
          : Colors.white; // White for WhiteTextBoxWrapper
      final borderColor = isBlueBox
          ? const Color(0xFF0974ba) // VVS blue border
          : Colors.grey[400]!; // Grey border for white box

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Html(
          data: content,
          style: {
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontSize: FontSize(16),
              lineHeight: const LineHeight(1.5),
            ),
            'p': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              lineHeight: const LineHeight(1.5),
            ),
            'sub': Style(
              fontSize: FontSize(12),
              verticalAlign: VerticalAlign.sub,
            ),
            'sup': Style(
              fontSize: FontSize(12),
              verticalAlign: VerticalAlign.sup,
            ),
            'a': Style(
              color: Colors.blue,
              textDecoration: TextDecoration.underline,
            ),
            'table': Style(
              margin: Margins.symmetric(vertical: 8),
            ),
          },
          extensions: [
            TagExtension(
              tagsToExtend: {'math'},
              builder: (extensionContext) {
                final mathml = extensionContext.element?.outerHtml ?? '';
                print('📐 Rendering MathML with flutter_math_fork');
                return _buildFormulaFromMathML(mathml, isBlueBox);
              },
            ),
          ],
          onLinkTap: (url, attributes, element) {
            if (url != null) {
              print('🔗 Link tapped: $url');
              // Handle link navigation here if needed
            }
          },
        ),
      );
    }

    // Fallback: just render the HTML
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        border: Border.all(color: const Color(0xFF0974ba), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Html(
        data: tableHtml,
        style: _getHtmlStyle(),
      ),
    );
  }

  // Build formula box from MathJax/MathML content
  // Build formula widget from MathML HTML (used in flutter_html TagExtension)
  Widget _buildFormulaFromMathML(String mathmlHtml, bool isBlueBox) {
    print('📐 Building formula from MathML');
    print(
        '📐 MathML HTML: ${mathmlHtml.substring(0, mathmlHtml.length > 200 ? 200 : mathmlHtml.length)}...');

    // Decode HTML entities
    final decodedContent = HtmlUnescape().convert(mathmlHtml);

    // Extract the main content from mstyle
    final mstyleMatch = RegExp(
      r'<mstyle[^>]*>(.*?)</mstyle>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(decodedContent);

    final mathContent =
        mstyleMatch != null ? (mstyleMatch.group(1) ?? '') : decodedContent;

    Widget? formulaWidget;
    String? formulaNumber;

    // Try to extract formula number from mtext
    final mtextMatch = RegExp(
      r'<mtext[^>]*>([^<]+)</mtext>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(mathContent);

    if (mtextMatch != null) {
      formulaNumber = mtextMatch.group(1)?.replaceAll('&nbsp;', ' ').trim();
      print('🔢 Formula number: $formulaNumber');
    }

    // Check if there's a fraction (mfrac)
    final mfracPattern = RegExp(
      r'<mfrac[^>]*>(.*?)</mfrac>',
      caseSensitive: false,
      dotAll: true,
    );
    final mfracMatches = mfracPattern.allMatches(mathContent).toList();

    if (mfracMatches.isNotEmpty) {
      print('🔢 Found ${mfracMatches.length} fraction(s)');

      // Build complete formula with multiple fractions
      final List<Widget> formulaChildren = [];
      int currentPos = 0;

      for (int i = 0; i < mfracMatches.length; i++) {
        final mfracMatch = mfracMatches[i];

        // Get content before this fraction
        if (currentPos < mfracMatch.start) {
          final beforeFrac =
              mathContent.substring(currentPos, mfracMatch.start);

          // Check for = sign
          final equalsMatch = RegExp(r'<mo[^>]*>=</mo>', caseSensitive: false)
              .firstMatch(beforeFrac);

          if (equalsMatch != null) {
            // Add left side
            if (equalsMatch.start > 0) {
              final leftSide = beforeFrac.substring(0, equalsMatch.start);
              formulaChildren.add(_buildMathMLWidget(leftSide, 18));
            }

            // Add = sign
            formulaChildren.add(const SizedBox(width: 8));
            formulaChildren.add(const Text('=',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)));
            formulaChildren.add(const SizedBox(width: 8));

            // Add content after = but before fraction
            if (equalsMatch.end < beforeFrac.length) {
              final afterEquals = beforeFrac.substring(equalsMatch.end);
              if (afterEquals.trim().isNotEmpty) {
                formulaChildren.add(_buildMathMLWidget(afterEquals, 18));
              }
            }
          } else {
            // No = sign, just add content
            if (beforeFrac.trim().isNotEmpty) {
              formulaChildren.add(_buildMathMLWidget(beforeFrac, 18));
            }
          }
        }

        // Parse and add the fraction
        final fractionContent = mfracMatch.group(1) ?? '';

        // Split into numerator and denominator
        final mrowPattern = RegExp(r'<mrow[^>]*>(.*?)</mrow>',
            caseSensitive: false, dotAll: true);
        final mrowMatches = mrowPattern.allMatches(fractionContent).toList();

        String numeratorMathML = '';
        String denominatorMathML = '';

        if (mrowMatches.length >= 2) {
          numeratorMathML = mrowMatches[0].group(1) ?? '';
          denominatorMathML = mrowMatches[1].group(1) ?? '';
        } else if (mrowMatches.length == 1) {
          numeratorMathML = mrowMatches[0].group(1) ?? '';
          denominatorMathML = fractionContent.substring(mrowMatches[0].end);
        } else {
          final halfPoint = fractionContent.length ~/ 2;
          numeratorMathML = fractionContent.substring(0, halfPoint);
          denominatorMathML = fractionContent.substring(halfPoint);
        }

        // Build fraction widget
        formulaChildren.add(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMathMLWidget(numeratorMathML, 16),
              Container(
                width: 80,
                height: 1.5,
                color: Colors.black,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
              _buildMathMLWidget(denominatorMathML, 16),
            ],
          ),
        );

        currentPos = mfracMatch.end;
      }

      // Add any remaining content after the last fraction
      if (currentPos < mathContent.length) {
        final afterLastFrac = mathContent.substring(currentPos);
        if (afterLastFrac.trim().isNotEmpty) {
          formulaChildren.add(_buildMathMLWidget(afterLastFrac, 18));
        }
      }

      // Build the complete formula
      formulaWidget = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: formulaChildren,
      );
    } else {
      // No fraction - simple inline formula
      formulaWidget = _buildMathMLWidget(mathContent, 18);
    }

    // Return formula widget with formula number if available
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        formulaWidget,
        if (formulaNumber != null) ...[
          const SizedBox(height: 8),
          Text(
            formulaNumber,
            style: TextStyle(
              fontSize: 14,
              color: isBlueBox ? Colors.blue[700] : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // Extract text from MathML content
  String _extractTextFromMathML(String mathml) {
    String result = mathml;

    // First, handle msub (subscript) elements - convert to text with subscript marker
    result = result.replaceAllMapped(
      RegExp(r'<msub[^>]*>(.*?)</msub>', caseSensitive: false, dotAll: true),
      (match) {
        final msubContent = match.group(1) ?? '';
        final miPattern = RegExp(r'<mi[^>]*>(.*?)</mi>', caseSensitive: false);
        final miMatches = miPattern.allMatches(msubContent).toList();

        if (miMatches.length >= 2) {
          final base = miMatches[0].group(1) ?? '';
          final subscript = miMatches[1].group(1) ?? '';
          return '$base$subscript'; // Combine for now, will handle in _buildMathText
        }
        return match.group(0) ?? '';
      },
    );

    // Now extract all elements in order
    final elements = <MapEntry<int, String>>[];

    // Extract mi (identifiers)
    final miPattern = RegExp(r'<mi[^>]*>(.*?)</mi>', caseSensitive: false);
    for (final match in miPattern.allMatches(result)) {
      elements.add(MapEntry(match.start, match.group(1) ?? ''));
    }

    // Extract mo (operators)
    final moPattern = RegExp(r'<mo[^>]*>(.*?)</mo>', caseSensitive: false);
    for (final match in moPattern.allMatches(result)) {
      var op = match.group(1) ?? '';
      op = _decodeHtmlEntities(op);
      if (op == '·') {
        elements.add(MapEntry(match.start, ' · '));
      } else if (op.trim().isNotEmpty) {
        elements.add(MapEntry(match.start, op));
      }
    }

    // Extract mn (numbers)
    final mnPattern = RegExp(r'<mn[^>]*>(.*?)</mn>', caseSensitive: false);
    for (final match in mnPattern.allMatches(result)) {
      elements.add(MapEntry(match.start, match.group(1) ?? ''));
    }

    // Sort by position to maintain order
    elements.sort((a, b) => a.key.compareTo(b.key));

    // Join the parts
    return elements.map((e) => e.value).join('');
  }

  // Build math text with subscripts
  Widget _buildMathText(String text, double fontSize) {
    // Check for subscript pattern (like Dh)
    final subscriptPattern = RegExp(r'([A-Za-z]+)([a-z])$');
    final match = subscriptPattern.firstMatch(text);

    if (match != null && match.group(1)!.length == 1) {
      final base = match.group(1)!;
      final subscript = match.group(2)!;

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            base,
            style: TextStyle(
              fontSize: fontSize,
              fontStyle: FontStyle.italic,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              subscript,
              style: TextStyle(
                fontSize: fontSize * 0.7,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    // No subscript, return normal text
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // Build widget from MathML content (handles subscripts and operators)
  Widget _buildMathMLWidget(String mathml, double fontSize) {
    final widgets = <Widget>[];

    // Find all msub (subscript) elements
    final msubPattern =
        RegExp(r'<msub[^>]*>(.*?)</msub>', caseSensitive: false, dotAll: true);
    final msubMatches = msubPattern.allMatches(mathml).toList();

    // Find all mi elements (outside of msub)
    final miPattern = RegExp(r'<mi[^>]*>(.*?)</mi>', caseSensitive: false);

    // Find all mo (operator) elements
    final moPattern = RegExp(r'<mo[^>]*>(.*?)</mo>', caseSensitive: false);

    // Build list of all elements with positions
    final elements = <MapEntry<int, dynamic>>[];

    // Add msub elements
    for (final match in msubMatches) {
      final msubContent = match.group(1) ?? '';
      final miMatches = miPattern.allMatches(msubContent).toList();
      if (miMatches.length >= 2) {
        final base = miMatches[0].group(1) ?? '';
        final subscript = miMatches[1].group(1) ?? '';
        elements.add(MapEntry(match.start,
            {'type': 'msub', 'base': base, 'subscript': subscript}));
      }
    }

    // Add mi elements that are NOT inside msub
    for (final match in miPattern.allMatches(mathml)) {
      // Check if this mi is inside any msub
      bool insideMsub = false;
      for (final msubMatch in msubMatches) {
        if (match.start >= msubMatch.start && match.end <= msubMatch.end) {
          insideMsub = true;
          break;
        }
      }
      if (!insideMsub) {
        elements.add(MapEntry(
            match.start, {'type': 'mi', 'text': match.group(1) ?? ''}));
      }
    }

    // Add mo elements
    for (final match in moPattern.allMatches(mathml)) {
      var op = match.group(1) ?? '';
      op = _decodeHtmlEntities(op);
      elements.add(MapEntry(match.start, {'type': 'mo', 'text': op}));
    }

    // Sort by position
    elements.sort((a, b) => a.key.compareTo(b.key));

    // Build widgets
    for (final element in elements) {
      final data = element.value as Map<String, dynamic>;

      if (data['type'] == 'msub') {
        // Build subscript widget
        widgets.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data['base'],
                style: TextStyle(
                  fontSize: fontSize,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 1),
                child: Text(
                  data['subscript'],
                  style: TextStyle(
                    fontSize: fontSize * 0.7,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (data['type'] == 'mi') {
        widgets.add(
          Text(
            data['text'],
            style: TextStyle(
              fontSize: fontSize,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (data['type'] == 'mo') {
        widgets.add(
          Text(
            data['text'],
            style: TextStyle(
              fontSize: fontSize,
            ),
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widgets.length == 1) {
      return widgets[0];
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: widgets,
    );
  }

  // Decode common HTML entities
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&middot;', '·')
        .replaceAll('&#183;', '·')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&ndash;', '–')
        .replaceAll('&#8211;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&#8212;', '—')
        .replaceAll('&times;', '×')
        .replaceAll('&#215;', '×')
        .replaceAll('&divide;', '÷')
        .replaceAll('&#247;', '÷');
  }

  // Clean MathJax content from table cells
  String _cleanMathJaxForCell(String content) {
    // Extract text from MathML <math> tag
    final mathMatch = RegExp(
      r'<math[^>]*>(.*?)</math>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(content);

    if (mathMatch != null) {
      final mathContent = mathMatch.group(1) ?? '';

      // Extract text from <mtext> tags
      final mtextPattern = RegExp(
        r'<mtext[^>]*>(.*?)</mtext>',
        caseSensitive: false,
        dotAll: true,
      );

      final mtextMatches = mtextPattern.allMatches(mathContent);
      if (mtextMatches.isNotEmpty) {
        final texts = <String>[];
        for (final match in mtextMatches) {
          String text = match.group(1) ?? '';
          // Clean up the text - remove inner tags but keep subscripts/superscripts
          text = text
              .replaceAllMapped(
                RegExp(r'<mi[^>]*>(.*?)</mi>', caseSensitive: false),
                (m) => m.group(1) ?? '',
              )
              .replaceAllMapped(
                RegExp(r'<mo[^>]*>(.*?)</mo>', caseSensitive: false),
                (m) => m.group(1) ?? '',
              )
              .replaceAllMapped(
                RegExp(r'<mn[^>]*>(.*?)</mn>', caseSensitive: false),
                (m) => m.group(1) ?? '',
              )
              .replaceAllMapped(
                RegExp(r'<msup[^>]*>(.*?)</msup>',
                    caseSensitive: false, dotAll: true),
                (m) {
                  final supContent = m.group(1) ?? '';
                  // Extract base and exponent
                  final parts =
                      RegExp(r'<m[in][^>]*>(.*?)</m[in]>', caseSensitive: false)
                          .allMatches(supContent)
                          .map((e) => e.group(1) ?? '')
                          .toList();
                  if (parts.length >= 2) {
                    return '${parts[0]}<sup>${parts[1]}</sup>';
                  }
                  return supContent;
                },
              )
              .replaceAll(RegExp(r'<span[^>]*>'), '')
              .replaceAll('</span>', '')
              .trim();

          if (text.isNotEmpty) {
            texts.add(text);
          }
        }

        if (texts.isNotEmpty) {
          return texts.join(' ');
        }
      }

      // If no mtext, try to extract from msub (for subscripts like Dh)
      final msubMatch = RegExp(
        r'<msub[^>]*>(.*?)</msub>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(mathContent);

      if (msubMatch != null) {
        final msubContent = msubMatch.group(1) ?? '';
        final miPattern = RegExp(r'<mi[^>]*>(.*?)</mi>', caseSensitive: false);
        final miMatches = miPattern.allMatches(msubContent).toList();

        if (miMatches.length >= 2) {
          final base = miMatches[0].group(1) ?? '';
          final subscript = miMatches[1].group(1) ?? '';
          return '$base<sub>$subscript</sub>';
        }
      }
    }

    // Fallback: remove MathJax span and script tags
    return content
        .replaceAll(
            RegExp(r'<span class="MathJax"[^>]*>.*?</span>',
                caseSensitive: false, dotAll: true),
            '')
        .replaceAll(
            RegExp(r'<script[^>]*>.*?</script>',
                caseSensitive: false, dotAll: true),
            '')
        .trim();
  }

  // Build extracted table widget
  Widget _buildExtractedTable(String tableHtml) {
    try {
      print('📊 DEBUG: Building table from HTML...');
      print('📊 DEBUG: Table HTML length: ${tableHtml.length}');

      // Check if this is a nested table (BlueTextBoxWrapper or WhiteTextBoxWrapper pattern)
      // These should be rendered as content boxes, not tables
      if (tableHtml.contains('BlueTextBoxWrapper') ||
          tableHtml.contains('WhiteTextBoxWrapper')) {
        print('📊 DEBUG: Detected TextBoxWrapper - rendering as content box');
        return _buildContentBox(tableHtml);
      }

      // Parse table rows
      final rowPattern =
          RegExp(r'<tr[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true);
      final rows = rowPattern.allMatches(tableHtml).toList();

      print('📊 DEBUG: Found ${rows.length} table rows');

      if (rows.isEmpty) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Tom tabell - ingen rader funnet',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        );
      }

      // Parse all rows with colspan/rowspan support
      final parsedRows = <List<TableCellData>>[];
      bool hasHeaders = false;

      for (int i = 0; i < rows.length; i++) {
        final cellContent = rows[i].group(1) ?? '';
        final cells = _parseTableCellsWithSpan(cellContent);
        if (cells.isNotEmpty) {
          parsedRows.add(cells);
          // Check if first row contains th elements (headers)
          if (i == 0 && cellContent.toLowerCase().contains('<th')) {
            hasHeaders = true;
          }
        }
      }

      if (parsedRows.isEmpty) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Tom tabell - ingen data funnet',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        );
      }

      // Calculate total columns needed (accounting for colspan)
      int maxColumns = 0;
      for (final row in parsedRows) {
        int rowWidth = 0;
        for (final cell in row) {
          rowWidth += cell.colspan;
        }
        if (rowWidth > maxColumns) {
          maxColumns = rowWidth;
        }
      }

      print('📊 DEBUG: Max columns (with colspan): $maxColumns');

      // Build table using Column of Rows (Table widget doesn't support colspan properly)
      final tableChildren = <Widget>[];

      // Track which cells span multiple rows
      final Map<int, int> activeRowspans = {}; // colIndex -> remaining rows

      for (int rowIndex = 0; rowIndex < parsedRows.length; rowIndex++) {
        final row = parsedRows[rowIndex];
        final rowWidgets = <Widget>[];
        int cellIndexInRow = 0;
        int currentColIndex = 0;

        // Determine background color for headers
        final isHeaderRow = hasHeaders && rowIndex == 0;

        // Process cells, accounting for rowspan from previous rows
        while (currentColIndex < maxColumns) {
          // Check if this column is occupied by a rowspan from a previous row
          if (activeRowspans.containsKey(currentColIndex) &&
              activeRowspans[currentColIndex]! > 0) {
            // This column is occupied by a rowspan, add an invisible placeholder
            rowWidgets.add(
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 0.5),
                  ),
                  // Empty container to maintain grid structure
                ),
              ),
            );
            activeRowspans[currentColIndex] =
                activeRowspans[currentColIndex]! - 1;
            if (activeRowspans[currentColIndex]! <= 0) {
              activeRowspans.remove(currentColIndex);
            }
            currentColIndex++;
            continue;
          }

          // Get the actual cell data if it exists
          if (cellIndexInRow < row.length) {
            final cell = row[cellIndexInRow];

            // Process cell content - clean MathJax if present
            String cellContent = cell.htmlContent;
            if (cellContent.contains('MathJax') ||
                cellContent.contains('<math')) {
              cellContent = _cleanMathJaxForCell(cellContent);
            }

            // Build the cell widget
            final cellWidget = Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 0.5),
                color: isHeaderRow ? Colors.grey[100] : null,
              ),
              child: Html(
                data: cellContent,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(14),
                    fontWeight:
                        isHeaderRow ? FontWeight.bold : FontWeight.normal,
                    textAlign: cell.align == TextAlign.center
                        ? TextAlign.center
                        : cell.align == TextAlign.right
                            ? TextAlign.right
                            : TextAlign.left,
                  ),
                  'sub': Style(
                    fontSize: FontSize(10),
                    verticalAlign: VerticalAlign.sub,
                  ),
                  'sup': Style(
                    fontSize: FontSize(10),
                    verticalAlign: VerticalAlign.sup,
                  ),
                },
              ),
            );

            // Add cell with colspan support using Expanded
            rowWidgets.add(
              Expanded(
                flex: cell.colspan,
                child: cellWidget,
              ),
            );

            // If this cell has rowspan > 1, track it for the columns it occupies
            if (cell.rowspan > 1) {
              for (int i = 0; i < cell.colspan; i++) {
                activeRowspans[currentColIndex + i] = cell.rowspan - 1;
              }
            }

            currentColIndex += cell.colspan;
            cellIndexInRow++;
          } else {
            // No more cells in this row, add empty cell
            rowWidgets.add(
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 0.5),
                  ),
                ),
              ),
            );
            currentColIndex++;
          }
        }

        tableChildren.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rowWidgets,
            ),
          ),
        );
      }

      // Use Column of Rows to build the table
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tableChildren,
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Error building table: $e');
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Feil ved parsing av tabell: $e',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
  }

  // Parse table cells with colspan and rowspan support
  List<TableCellData> _parseTableCellsWithSpan(String rowHtml) {
    print('📊 DEBUG: Parsing table cells with span from: $rowHtml');

    final cellPattern = RegExp(
      r'<t([hd])\s*([^>]*)>(.*?)</t\1>',
      caseSensitive: false,
      dotAll: true,
    );

    final cells = <TableCellData>[];

    for (final match in cellPattern.allMatches(rowHtml)) {
      final attributes = match.group(2) ?? '';
      final content = match.group(3) ?? '';

      // Parse colspan
      int colspan = 1;
      final colspanMatch = RegExp(
              r'colspan\s*=\s*["' r"'" r']?(\d+)["' r"'" r']?',
              caseSensitive: false)
          .firstMatch(attributes);
      if (colspanMatch != null) {
        colspan = int.tryParse(colspanMatch.group(1) ?? '1') ?? 1;
      }

      // Parse rowspan (not fully supported yet, but we parse it)
      int rowspan = 1;
      final rowspanMatch = RegExp(
              r'rowspan\s*=\s*["' r"'" r']?(\d+)["' r"'" r']?',
              caseSensitive: false)
          .firstMatch(attributes);
      if (rowspanMatch != null) {
        rowspan = int.tryParse(rowspanMatch.group(1) ?? '1') ?? 1;
      }

      // Parse align
      TextAlign align = TextAlign.left;
      final alignMatch = RegExp(
              r'align\s*=\s*["' r"'" r']?(left|center|right)["' r"'" r']?',
              caseSensitive: false)
          .firstMatch(attributes);
      if (alignMatch != null) {
        final alignValue = alignMatch.group(1)?.toLowerCase();
        if (alignValue == 'center') {
          align = TextAlign.center;
        } else if (alignValue == 'right') {
          align = TextAlign.right;
        }
      }

      final text = _stripHtmlTags(content);

      cells.add(TableCellData(
        text: text,
        htmlContent: content, // Store original HTML content
        colspan: colspan,
        rowspan: rowspan,
        align: align,
      ));

      print(
          '📊 DEBUG: Parsed cell: "$text" (colspan: $colspan, rowspan: $rowspan, align: $align)');
    }

    return cells;
  }

  // Strip HTML tags from text
  String _stripHtmlTags(String htmlText) {
    print('📊 DEBUG: Stripping HTML from: "$htmlText"');

    // First handle subscript and superscript with Unicode equivalents
    String result = htmlText;

    // Handle subscript (with dotAll to match across newlines)
    result = result.replaceAllMapped(
      RegExp(r'<sub[^>]*>(.*?)</sub>', caseSensitive: false, dotAll: true),
      (match) {
        final innerHtml = match.group(1) ?? '';
        // Strip any inner HTML tags first
        final text = innerHtml.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        // Convert to Unicode subscript characters
        return _convertToSubscript(text);
      },
    );

    // Handle superscript (with dotAll to match across newlines)
    result = result.replaceAllMapped(
      RegExp(r'<sup[^>]*>(.*?)</sup>', caseSensitive: false, dotAll: true),
      (match) {
        final innerHtml = match.group(1) ?? '';
        // Strip any inner HTML tags first
        final text = innerHtml.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        // Convert to Unicode superscript characters
        return _convertToSuperscript(text);
      },
    );

    // Now remove all other HTML tags
    result = result
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&ndash;', '–') // En dash
        .replaceAll('&#8211;', '–') // En dash numeric
        .replaceAll('&mdash;', '—') // Em dash
        .replaceAll('&#8212;', '—') // Em dash numeric
        .replaceAll('&middot;', '·') // Middle dot (multiplication)
        .replaceAll('&#183;', '·') // Middle dot numeric
        .replaceAll('&bull;', '•') // Bullet point
        .replaceAll('&#8226;', '•') // Bullet point numeric
        // Greek letters
        .replaceAll('&lambda;', 'λ') // Lambda
        .replaceAll('&#955;', 'λ') // Lambda numeric
        .replaceAll('&Lambda;', 'Λ') // Capital Lambda
        .replaceAll('&#923;', 'Λ') // Capital Lambda numeric
        .replaceAll('&alpha;', 'α') // Alpha
        .replaceAll('&#945;', 'α') // Alpha numeric
        .replaceAll('&beta;', 'β') // Beta
        .replaceAll('&#946;', 'β') // Beta numeric
        .replaceAll('&gamma;', 'γ') // Gamma
        .replaceAll('&#947;', 'γ') // Gamma numeric
        .replaceAll('&delta;', 'δ') // Delta
        .replaceAll('&#948;', 'δ') // Delta numeric
        .replaceAll('&epsilon;', 'ε') // Epsilon
        .replaceAll('&#949;', 'ε') // Epsilon numeric
        .replaceAll('&eta;', 'η') // Eta
        .replaceAll('&#951;', 'η') // Eta numeric
        .replaceAll('&theta;', 'θ') // Theta
        .replaceAll('&#952;', 'θ') // Theta numeric
        .replaceAll('&mu;', 'μ') // Mu
        .replaceAll('&#956;', 'μ') // Mu numeric
        .replaceAll('&pi;', 'π') // Pi
        .replaceAll('&#960;', 'π') // Pi numeric
        .replaceAll('&rho;', 'ρ') // Rho
        .replaceAll('&#961;', 'ρ') // Rho numeric
        .replaceAll('&sigma;', 'σ') // Sigma
        .replaceAll('&#963;', 'σ') // Sigma numeric
        .replaceAll('&tau;', 'τ') // Tau
        .replaceAll('&#964;', 'τ') // Tau numeric
        .replaceAll('&phi;', 'φ') // Phi
        .replaceAll('&#966;', 'φ') // Phi numeric
        .replaceAll('&omega;', 'ω') // Omega
        .replaceAll('&#969;', 'ω') // Omega numeric
        .replaceAll('&Omega;', 'Ω') // Capital Omega
        .replaceAll('&#937;', 'Ω') // Capital Omega numeric
        .replaceAll('&deg;', '°')
        .replaceAll('&#176;', '°')
        .replaceAll('&plusmn;', '±')
        .replaceAll('&#177;', '±')
        .replaceAll('&times;', '×')
        .replaceAll('&#215;', '×')
        .replaceAll('&divide;', '÷')
        .replaceAll('&#247;', '÷')
        .replaceAll('&frac12;', '½')
        .replaceAll('&#189;', '½')
        .replaceAll('&frac14;', '¼')
        .replaceAll('&#188;', '¼')
        .replaceAll('&frac34;', '¾')
        .replaceAll('&#190;', '¾')
        .replaceAll('&micro;', 'µ')
        .replaceAll('&#181;', 'µ')
        .replaceAll('&euro;', '€')
        .replaceAll('&#8364;', '€')
        .replaceAll('&pound;', '£')
        .replaceAll('&#163;', '£')
        .replaceAll('&yen;', '¥')
        .replaceAll('&#165;', '¥')
        .replaceAll('&sup2;', '²')
        .replaceAll('&#178;', '²')
        .replaceAll('&sup3;', '³')
        .replaceAll('&#179;', '³')
        .replaceAll('&aring;', 'å')
        .replaceAll('&Aring;', 'Å')
        .replaceAll('&#229;', 'å')
        .replaceAll('&#197;', 'Å')
        .replaceAll('&oslash;', 'ø')
        .replaceAll('&Oslash;', 'Ø')
        .replaceAll('&#248;', 'ø')
        .replaceAll('&#216;', 'Ø')
        .replaceAll('&aelig;', 'æ')
        .replaceAll('&Aelig;', 'Æ')
        .replaceAll('&#230;', 'æ')
        .replaceAll('&#198;', 'Æ')
        .trim();
    print('📊 DEBUG: Stripped result: "$result"');
    return result;
  }

  // Convert text to Unicode subscript characters
  String _convertToSubscript(String text) {
    String result = text;
    // Numbers
    result = result
        .replaceAll('0', '₀')
        .replaceAll('1', '₁')
        .replaceAll('2', '₂')
        .replaceAll('3', '₃')
        .replaceAll('4', '₄')
        .replaceAll('5', '₅')
        .replaceAll('6', '₆')
        .replaceAll('7', '₇')
        .replaceAll('8', '₈')
        .replaceAll('9', '₉');
    // Lowercase letters (limited Unicode support)
    result = result
        .replaceAll('a', 'ₐ')
        .replaceAll('e', 'ₑ')
        .replaceAll('h', 'ₕ')
        .replaceAll('i', 'ᵢ')
        .replaceAll('j', 'ⱼ')
        .replaceAll('k', 'ₖ')
        .replaceAll('l', 'ₗ')
        .replaceAll('m', 'ₘ')
        .replaceAll('n', 'ₙ')
        .replaceAll('o', 'ₒ')
        .replaceAll('p', 'ₚ')
        .replaceAll('r', 'ᵣ')
        .replaceAll('s', 'ₛ')
        .replaceAll('t', 'ₜ')
        .replaceAll('u', 'ᵤ')
        .replaceAll('v', 'ᵥ')
        .replaceAll('x', 'ₓ');
    // Symbols
    result = result
        .replaceAll('+', '₊')
        .replaceAll('-', '₋')
        .replaceAll('=', '₌')
        .replaceAll('(', '₍')
        .replaceAll(')', '₎');
    return result;
  }

  // Convert text to Unicode superscript characters
  String _convertToSuperscript(String text) {
    String result = text;
    // Numbers
    result = result
        .replaceAll('0', '⁰')
        .replaceAll('1', '¹')
        .replaceAll('2', '²')
        .replaceAll('3', '³')
        .replaceAll('4', '⁴')
        .replaceAll('5', '⁵')
        .replaceAll('6', '⁶')
        .replaceAll('7', '⁷')
        .replaceAll('8', '⁸')
        .replaceAll('9', '⁹');
    // Letters (limited Unicode support)
    result = result
        .replaceAll('a', 'ᵃ')
        .replaceAll('b', 'ᵇ')
        .replaceAll('c', 'ᶜ')
        .replaceAll('d', 'ᵈ')
        .replaceAll('e', 'ᵉ')
        .replaceAll('f', 'ᶠ')
        .replaceAll('g', 'ᵍ')
        .replaceAll('h', 'ʰ')
        .replaceAll('i', 'ⁱ')
        .replaceAll('j', 'ʲ')
        .replaceAll('k', 'ᵏ')
        .replaceAll('l', 'ˡ')
        .replaceAll('m', 'ᵐ')
        .replaceAll('n', 'ⁿ')
        .replaceAll('o', 'ᵒ')
        .replaceAll('p', 'ᵖ')
        .replaceAll('r', 'ʳ')
        .replaceAll('s', 'ˢ')
        .replaceAll('t', 'ᵗ')
        .replaceAll('u', 'ᵘ')
        .replaceAll('v', 'ᵛ')
        .replaceAll('w', 'ʷ')
        .replaceAll('x', 'ˣ')
        .replaceAll('y', 'ʸ')
        .replaceAll('z', 'ᶻ');
    // Symbols
    result = result
        .replaceAll('+', '⁺')
        .replaceAll('-', '⁻')
        .replaceAll('=', '⁼')
        .replaceAll('(', '⁽')
        .replaceAll(')', '⁾');
    return result;
  }

  // Get HTML style configuration
  Map<String, Style> _getHtmlStyle() {
    return {
      'body': Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        fontSize: FontSize(16),
        lineHeight: const LineHeight(1.5),
        color: Colors.black87,
      ),
      'h1': Style(
        fontSize: FontSize(22),
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        margin: Margins.only(top: 16, bottom: 12),
      ),
      'h2': Style(
        fontSize: FontSize(20),
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        margin: Margins.only(top: 14, bottom: 10),
      ),
      'h3': Style(
        fontSize: FontSize(18),
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        margin: Margins.only(top: 12, bottom: 8),
      ),
      'p': Style(
        margin: Margins.only(bottom: 12),
        lineHeight: const LineHeight(1.5),
      ),
      'ul': Style(
        margin: Margins.only(bottom: 12),
      ),
      'ol': Style(
        margin: Margins.only(bottom: 12),
      ),
      'li': Style(
        margin: Margins.only(bottom: 4),
      ),
      'blockquote': Style(
        backgroundColor: Colors.blue[50],
        padding: HtmlPaddings.all(12),
        border: Border(left: BorderSide(color: Colors.blue[300]!, width: 4)),
        margin: Margins.only(bottom: 12),
        fontStyle: FontStyle.italic,
      ),
      'code': Style(
        backgroundColor: Colors.grey[200],
        padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        fontFamily: 'monospace',
        fontSize: FontSize(14),
      ),
      'pre': Style(
        backgroundColor: Colors.grey[100],
        padding: HtmlPaddings.all(12),
        margin: Margins.only(bottom: 12),
        fontFamily: 'monospace',
        fontSize: FontSize(14),
        whiteSpace: WhiteSpace.pre,
      ),
      'img': Style(
        margin: Margins.only(bottom: 12),
      ),
      'sub': Style(
        fontSize: FontSize(12),
        verticalAlign: VerticalAlign.sub,
      ),
      'sup': Style(
        fontSize: FontSize(12),
        verticalAlign: VerticalAlign.sup,
      ),
    };
  }

  void _handleLinkTap(String? url, BuildContext context) {
    if (url == null) return;

    print('🔗 Link tapped: $url');

    // Check if it's a local file (cached document)
    if (url.startsWith('file://')) {
      print('📄 Opening local document: $url');
      _openLocalDocument(url, context);
      return;
    }

    // For network links, show URL
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lenke: $url'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  // Handle downloadable file: check local first, then open URL in browser
  Future<void> _handleDownloadableFileAsync(
      String url, BuildContext context) async {
    try {
      print('📥 Handling downloadable file: $url');

      // Check if we have the file locally
      final hasLocal = await _checkAndOpenLocalFile(url, context);

      if (hasLocal) {
        print('✅ Opened local file');
        return;
      }

      // No local file - open URL in browser
      print('🌐 Opening downloadable file in external browser');
      final fileUri = Uri.parse(url);
      if (await canLaunchUrl(fileUri)) {
        final launched = await launchUrl(
          fileUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          print('✅ Successfully launched URL in browser');
        } else {
          print('❌ Failed to launch URL');
        }
      } else {
        print('❌ Cannot launch URL: $url');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kunne ikke åpne filen'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error handling downloadable file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feil ved åpning av fil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Check if downloadable file exists locally and open it
  // Returns true if file was found and opened, false otherwise
  Future<bool> _checkAndOpenLocalFile(String url, BuildContext context) async {
    try {
      print('📥 Checking for local file: $url');

      // Extract filename from URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final urlFileName = pathSegments.isNotEmpty ? pathSegments.last : '';

      if (urlFileName.isEmpty) {
        print('❌ Could not extract filename from URL');
        return false;
      }

      print('📁 Looking for: $urlFileName');

      // Check if file exists in media directory
      final directory = await getApplicationDocumentsDirectory();
      final mediaDir =
          Directory('${directory.path}/${widget.publication.id}_media');

      if (!await mediaDir.exists()) {
        print('❌ Media directory does not exist');
        return false;
      }

      print('📂 Searching in: ${mediaDir.path}');

      // List all files in media directory
      final allFiles = await mediaDir.list().toList();

      // Try to find the file
      for (final file in allFiles) {
        if (file is File) {
          final localFileName = file.path.split(Platform.pathSeparator).last;

          // Match if the local filename ends with the URL filename
          // (handles cases like "qxfis1ds-klimadata.xls" matching "klimadata.xls")
          if (localFileName.toLowerCase().endsWith(urlFileName.toLowerCase())) {
            print('✅ Found local file: $localFileName');

            // Open the local file
            final localFileUrl = 'file://${file.path}';
            await _openLocalDocument(localFileUrl, context);
            return true;
          }
        }
      }

      print('❌ File not found in media directory');
      return false;
    } catch (e) {
      print('❌ Error checking for local file: $e');
      return false;
    }
  }

  Future<void> _openLocalDocument(String fileUrl, BuildContext context) async {
    try {
      final filePath = fileUrl.substring(7); // Remove 'file://'
      final file = File(filePath);

      if (await file.exists()) {
        final fileName = filePath.split(Platform.pathSeparator).last;
        final extension = fileName.contains('.')
            ? fileName.split('.').last.toLowerCase()
            : '';

        print('📄 Opening document: $fileName (.$extension)');

        // Show dialog with file info
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: Row(
                children: [
                  Icon(
                    _getFileIcon(extension),
                    color: const Color(0xFF0974ba),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Dokument lastet ned',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dokumentet er lagret lokalt:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF0974ba).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getFileIcon(extension),
                          color: const Color(0xFF0974ba),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<int>(
                                future: file.length(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Text(
                                      _formatFileSize(snapshot.data!),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dokumentet er tilgjengelig offline. Åpne med en ekstern app for å se innholdet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Lukk'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _shareOrOpenFile(file, context);
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Åpne'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0974ba),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        print('❌ File does not exist: $filePath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumentet er ikke lastet ned ennå'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error opening document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feil ved åpning av dokument: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getFileIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Future<void> _shareOrOpenFile(File file, BuildContext context) async {
    try {
      print('📂 Attempting to open file: ${file.path}');

      // Use open_file package which handles Android FileProvider properly
      final result = await OpenFile.open(file.path);

      print('🔍 Open file result: ${result.type} - ${result.message}');

      if (result.type == ResultType.done) {
        print('✅ File opened successfully');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumentet åpnes...'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (result.type == ResultType.noAppToOpen) {
        print('⚠️ No app to open this file type');
        throw Exception('Ingen app tilgjengelig for å åpne denne filtypen');
      } else if (result.type == ResultType.fileNotFound) {
        print('❌ File not found');
        throw Exception('Filen ble ikke funnet');
      } else if (result.type == ResultType.permissionDenied) {
        print('❌ Permission denied');
        throw Exception('Tilgang nektet');
      } else {
        print('❌ Unknown error: ${result.message}');
        throw Exception(result.message);
      }
    } catch (e) {
      print('❌ Error opening file: $e');

      if (context.mounted) {
        // Show error with file path as fallback
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('Kunne ikke åpne fil'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filen kunne ikke åpnes automatisk. Du kan finne den på:',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    file.path,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tips: Installer en PDF-leser eller dokumentvisningsapp fra App Store/Google Play.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  bool _hasPreviousChapter() {
    // This method is called synchronously, so we can't load chapters here
    // We'll handle the logic in _navigateToPrevious instead
    // For now, always return true to enable the button
    // The actual check will happen in _navigateToPrevious
    return true;
  }

  bool _hasNextChapter() {
    // This method is called synchronously, so we can't load chapters here
    // We'll handle the logic in _navigateToNext instead
    // For now, always return true to enable the button
    // The actual check will happen in _navigateToNext
    return true;
  }

  Widget _buildFloatingNavigationBar(BuildContext context) {
    // Only show navigation if we have the required data
    if (widget.allSubchapters == null || widget.currentIndex == null) {
      return const SizedBox.shrink();
    }

    final hasPrevious = widget.currentIndex! > 0 || _hasPreviousChapter();
    final hasNext = widget.currentIndex! < widget.allSubchapters!.length - 1 ||
        _hasNextChapter();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1 * 255),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button
              FloatingActionButton.extended(
                onPressed:
                    hasPrevious ? () => _navigateToPrevious(context) : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Forrige'),
                backgroundColor: hasPrevious
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300],
                foregroundColor: hasPrevious ? Colors.white : Colors.grey[600],
                heroTag: 'previous',
              ),

              // Page indicator
              Text(
                '${widget.currentIndex! + 1} av ${widget.allSubchapters!.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              // Next button
              FloatingActionButton.extended(
                onPressed: hasNext ? () => _navigateToNext(context) : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Neste'),
                backgroundColor:
                    hasNext ? Theme.of(context).primaryColor : Colors.grey[300],
                foregroundColor: hasNext ? Colors.white : Colors.grey[600],
                heroTag: 'next',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPrevious(BuildContext context) async {
    if (widget.allSubchapters != null && widget.currentIndex != null) {
      // Check if there's a previous subchapter in current chapter
      if (widget.currentIndex! > 0) {
        final previousSubchapter =
            widget.allSubchapters![widget.currentIndex! - 1];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NewSubchapterDetailScreen(
              publication: widget.publication,
              chapter: widget.chapter,
              subchapter: previousSubchapter,
              allSubchapters: widget.allSubchapters,
              currentIndex: widget.currentIndex! - 1,
            ),
          ),
        );
      } else {
        // First subchapter in current chapter - try to go to previous chapter
        await _navigateToPreviousChapter(context);
      }
    }
  }

  Future<void> _navigateToPreviousChapter(BuildContext context) async {
    try {
      // Load all chapters to find the previous chapter
      final chapters = await NewPublicationService.instance
          .loadPublicationContent(widget.publication.id);

      if (chapters != null) {
        // Find current chapter index
        int currentChapterIndex = -1;
        for (int i = 0; i < chapters.length; i++) {
          if (chapters[i].title == widget.chapter.title) {
            currentChapterIndex = i;
            break;
          }
        }

        // Check if there's a previous chapter
        if (currentChapterIndex > 0) {
          final previousChapter = chapters[currentChapterIndex - 1];

          // Get the last subchapter of the previous chapter
          if (previousChapter.subchapters.isNotEmpty) {
            final lastSubchapter = previousChapter.subchapters.last;
            final lastIndex = previousChapter.subchapters.length - 1;

            Navigator.pushReplacement(
              context, // ignore: use_build_context_synchronously
              MaterialPageRoute(
                builder: (context) => NewSubchapterDetailScreen(
                  publication: widget.publication,
                  chapter: previousChapter,
                  subchapter: lastSubchapter,
                  allSubchapters: previousChapter.subchapters,
                  currentIndex: lastIndex,
                ),
              ),
            );
          } else {
            // Previous chapter has no subchapters
            ScaffoldMessenger.of(context).showSnackBar(
              // ignore: use_build_context_synchronously
              const SnackBar(
                content: Text('Forrige kapittel har ingen avsnitt'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          // No more chapters
          ScaffoldMessenger.of(context).showSnackBar(
            // ignore: use_build_context_synchronously
            const SnackBar(
              content: Text('Du er på første kapittel'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      // Error navigating to previous chapter
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        // ignore: use_build_context_synchronously
        const SnackBar(
          content: Text('Kunne ikke navigere til forrige kapittel'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToNext(BuildContext context) async {
    if (widget.allSubchapters != null && widget.currentIndex != null) {
      // Check if there's a next subchapter in current chapter
      if (widget.currentIndex! < widget.allSubchapters!.length - 1) {
        final nextSubchapter = widget.allSubchapters![widget.currentIndex! + 1];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NewSubchapterDetailScreen(
              publication: widget.publication,
              chapter: widget.chapter,
              subchapter: nextSubchapter,
              allSubchapters: widget.allSubchapters,
              currentIndex: widget.currentIndex! + 1,
            ),
          ),
        );
      } else {
        // Last subchapter in current chapter - try to go to next chapter
        await _navigateToNextChapter(context);
      }
    }
  }

  Future<void> _navigateToNextChapter(BuildContext context) async {
    try {
      // Load all chapters to find the next chapter
      final chapters = await NewPublicationService.instance
          .loadPublicationContent(widget.publication.id);

      if (chapters != null) {
        // Find current chapter index
        int currentChapterIndex = -1;
        for (int i = 0; i < chapters.length; i++) {
          if (chapters[i].title == widget.chapter.title) {
            currentChapterIndex = i;
            break;
          }
        }

        // Check if there's a next chapter
        if (currentChapterIndex >= 0 &&
            currentChapterIndex < chapters.length - 1) {
          final nextChapter = chapters[currentChapterIndex + 1];

          // Get the first subchapter of the next chapter
          if (nextChapter.subchapters.isNotEmpty) {
            final firstSubchapter = nextChapter.subchapters[0];

            Navigator.pushReplacement(
              context, // ignore: use_build_context_synchronously
              MaterialPageRoute(
                builder: (context) => NewSubchapterDetailScreen(
                  publication: widget.publication,
                  chapter: nextChapter,
                  subchapter: firstSubchapter,
                  allSubchapters: nextChapter.subchapters,
                  currentIndex: 0,
                ),
              ),
            );
          } else {
            // Next chapter has no subchapters
            ScaffoldMessenger.of(context).showSnackBar(
              // ignore: use_build_context_synchronously
              const SnackBar(
                content: Text('Neste kapittel har ingen avsnitt'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          // No more chapters
          ScaffoldMessenger.of(context).showSnackBar(
            // ignore: use_build_context_synchronously
            const SnackBar(
              content: Text('Du er på siste kapittel'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      // Error navigating to next chapter
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        // ignore: use_build_context_synchronously
        const SnackBar(
          content: Text('Kunne ikke navigere til neste kapittel'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareContent(BuildContext context) {
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deling ikke implementert ennå'),
      ),
    );
  }

  Future<void> _checkIfBookmarked() async {
    try {
      final userDataService = UserDataService.instance;
      final userData = await userDataService.loadUserData();

      if (userData != null) {
        final bookmarkId =
            '${widget.publication.id}_${widget.chapter.title}_${widget.subchapter.title}';
        final isBookmarked = userData.bookmarks.any((b) => b.id == bookmarkId);

        if (mounted) {
          setState(() {
            _isBookmarked = isBookmarked;
          });
        }
      }
    } catch (e) {
      print('❌ Error checking bookmark status: $e');
    }
  }

  Future<void> _toggleBookmark() async {
    try {
      final userDataService = UserDataService.instance;
      final userData = await userDataService.loadUserData();

      if (userData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kunne ikke laste brukerdata')),
          );
        }
        return;
      }

      final bookmarkId =
          '${widget.publication.id}_${widget.chapter.title}_${widget.subchapter.title}';
      final bookmarks = List<BookmarkedSubchapter>.from(userData.bookmarks);

      if (_isBookmarked) {
        // Remove bookmark
        bookmarks.removeWhere((b) => b.id == bookmarkId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bokmerke fjernet')),
          );
        }
      } else {
        // Add bookmark
        final newBookmark = BookmarkedSubchapter(
          publicationId: widget.publication.id,
          publicationName: widget.publication.name,
          chapterTitle: widget.chapter.title,
          subchapterTitle: widget.subchapter.title,
          subchapterNumber: widget.subchapter.number,
          bookmarkedAt: DateTime.now(),
        );
        bookmarks.add(newBookmark);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bokmerke lagt til')),
          );
        }
      }

      // Save updated user data
      final updatedUserData = UserData(
        email: userData.email,
        subscriptions: userData.subscriptions,
        availablePublications: userData.availablePublications,
        bookmarks: bookmarks,
        lastUpdated: DateTime.now(),
      );

      await userDataService.saveUserData(updatedUserData);

      if (mounted) {
        setState(() {
          _isBookmarked = !_isBookmarked;
        });
      }
    } catch (e) {
      print('❌ Error toggling bookmark: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunne ikke lagre bokmerke')),
        );
      }
    }
  }

  // Build image widget (cached or network)
  Widget _buildImageWidget(String src) {
    print('🖼️ _buildImageWidget called with src: $src');

    // For ALL images (cached://, http, or any other URL), try to find the cached file
    // This follows the old implementation pattern using getCachedContentImageFile
    return FutureBuilder<File?>(
      future: _findCachedImageForUrl(src),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 150,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: Image.file(
              snapshot.data!,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('❌ Error loading cached image: $error');
                return _buildImageErrorWidget('Feil ved lasting av bilde', src);
              },
            ),
          );
        } else {
          print('❌ Cached image file not found for: $src');
          // Try to load network image as fallback for testing
          if (src.startsWith('http')) {
            return _buildNetworkImageFallback(src);
          }
          return _buildImageErrorWidget('Bilde ikke funnet i cache', src);
        }
      },
    );
  }

  // Find cached image file for a given URL (matches old implementation pattern)
  Future<File?> _findCachedImageForUrl(String imageUrl) async {
    try {
      print('🔍 Searching for cached image for URL: $imageUrl');

      // If it's a local file:// URL, return the file directly
      if (imageUrl.startsWith('file://')) {
        final filePath = imageUrl.substring(7); // Remove 'file://'
        final file = File(filePath);
        if (await file.exists()) {
          print('✅ Found local file: $filePath');
          return file;
        } else {
          print('❌ Local file does not exist: $filePath');
          return null;
        }
      }

      // Extract filename from the URL path
      // e.g., "/media/hvljumra/styring_og_reg_banner.png" -> "styring_og_reg_banner.png"
      String fileName = imageUrl;
      if (imageUrl.contains('/')) {
        fileName = imageUrl.split('/').last;
      }

      print('📁 Extracted filename: $fileName');

      // Search for this file in the publication's media directory
      final directory = await getApplicationDocumentsDirectory();
      final mediaDir =
          Directory('${directory.path}/${widget.publication.id}_media');

      print('📂 Looking in media directory: ${mediaDir.path}');

      if (await mediaDir.exists()) {
        print('✅ Media directory exists');

        // First, list ALL files in the directory for debugging
        final allFiles = await mediaDir.list().toList();
        print(
            '📋 === ALL FILES IN MEDIA DIRECTORY (${allFiles.length} total) ===');
        for (final file in allFiles) {
          if (file is File) {
            final existingFileName =
                file.path.split(Platform.pathSeparator).last;
            print('  📄 $existingFileName');
          }
        }
        print('📋 === END OF FILE LIST ===');

        // Look for file with exact filename
        final imageFile = File('${mediaDir.path}/$fileName');

        if (await imageFile.exists()) {
          print('✅ Found image file: ${imageFile.path}');
          return imageFile;
        } else {
          print('❌ Image file not found: ${imageFile.path}');

          // Try case-insensitive search
          print(
              '🔍 Searching among ${allFiles.length} files for case-insensitive match...');
          print('🎯 Looking for: "$fileName" (length: ${fileName.length})');

          for (final file in allFiles) {
            if (file is File) {
              final existingFileName =
                  file.path.split(Platform.pathSeparator).last;
              final existingLower = existingFileName.toLowerCase();
              final searchLower = fileName.toLowerCase();

              print('  Comparing: "$existingFileName" vs "$fileName"');
              print('    Lower: "$existingLower" vs "$searchLower"');
              print('    Match: ${existingLower == searchLower}');

              if (existingLower == searchLower) {
                print('✅ Found case-insensitive match: ${file.path}');
                return file;
              }
            }
          }

          print('❌ No matching file found in media directory');
        }
      } else {
        print('❌ Media directory does not exist: ${mediaDir.path}');
      }

      // Fallback: try old cached:// URL pattern
      if (imageUrl.startsWith('cached://')) {
        final cachedPath = imageUrl.substring(9); // Remove 'cached://'
        final parts = cachedPath.split('_');
        if (parts.length >= 4) {
          final indexPart = parts.last.replaceAll('.img', '');
          final index = int.tryParse(indexPart);
          if (index != null) {
            return await NewPublicationService.instance
                .getCachedImageFile(widget.publication.id, index);
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error finding cached image: $e');
      return null;
    }
  }

  Widget _buildNetworkImageFallback(String src) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Image.network(
        src,
        width: double.infinity,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 150,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading network image: $error');
          return _buildImageErrorWidget(
              'Feil ved lasting av nettverksbilde', src);
        },
      ),
    );
  }

  Widget _buildImageErrorWidget(String message, String src) {
    return Container(
      height: 150,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Colors.red[600], size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.red[800],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              src,
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Vimeo WebView widget for embedded video playback
class VimeoWebView extends StatelessWidget {
  final String embedUrl;

  const VimeoWebView({required this.embedUrl, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setBackgroundColor(Colors.black)
              ..loadRequest(Uri.parse(embedUrl)),
          ),
        ),
      ),
    );
  }
}
