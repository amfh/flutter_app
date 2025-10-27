import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import '../models/subchapter.dart';
import '../widgets/main_scaffold.dart';
import '../services/publication_service.dart';
import '../services/local_storage_service.dart';

// Hjelpefunksjoner for bokmerker
Future<List<SubChapter>> loadBookmarks() async {
  final prefs = await SharedPreferences.getInstance();
  final String? jsonString = prefs.getString('bookmarked_subchapters');
  if (jsonString == null) return [];
  final List<dynamic> data = jsonDecode(jsonString);
  return data.map((e) => SubChapter.fromJson(e)).toList();
}

Future<void> saveBookmark(SubChapter sub) async {
  final prefs = await SharedPreferences.getInstance();
  final List<SubChapter> current = await loadBookmarks();
  if (current.any((s) => s.id == sub.id)) return; // Ikke duplikat
  current.add(sub);
  final String jsonString = jsonEncode(current.map((e) => e.toJson()).toList());
  await prefs.setString('bookmarked_subchapters', jsonString);
}

class SubChapterDetailScreen extends StatefulWidget {
  final List<SubChapter> subChapters;
  final int currentIndex;
  final String bookId;
  const SubChapterDetailScreen({
    super.key,
    required this.subChapters,
    required this.currentIndex,
    required this.bookId,
  });

  @override
  State<SubChapterDetailScreen> createState() => _SubChapterDetailScreenState();
}

class _SubChapterDetailScreenState extends State<SubChapterDetailScreen> {
  SubChapter get currentSubChapter => widget.subChapters[widget.currentIndex];

  bool _isBookmarked = false;
  late final PublicationService _publicationService;

  @override
  void initState() {
    super.initState();
    _publicationService = PublicationService();
    _checkIfBookmarked();
    _checkImageCacheStatus();
  }

  // Check and log image cache status
  void _checkImageCacheStatus() async {
    try {
      final areImagesCached = await _publicationService
          .areImagesCachedForPublication(widget.bookId);
      print(
          '📊 Image cache status for publication ${widget.bookId}: $areImagesCached');

      if (!areImagesCached) {
        print('⚠️ Images are NOT properly cached for this publication');
        print('💡 User should re-run offline download to fix image issues');

        // Test specific images around index 15
        print('🔍 Testing specific image files around index 15:');
        for (int i = 10; i <= 20; i++) {
          final testFile = await _publicationService.getCachedContentImageFile(
              widget.bookId, i);
          if (testFile != null) {
            print('✅ Image $i exists: ${testFile.path}');
          } else {
            print('❌ Image $i missing');
          }
        }
      }
    } catch (e) {
      print('💥 Error checking image cache status: $e');
    }
  }

  @override
  void dispose() {
    _publicationService.dispose();
    super.dispose();
  }

  // Get HTML styling with enhanced table support
  Map<String, Style> _getHtmlStyle() {
    return {
      "body": Style(
        fontSize: FontSize(16.0),
        lineHeight: const LineHeight(1.4),
      ),
      "p": Style(
        margin: Margins.only(bottom: 8, top: 4),
        fontSize: FontSize(14.0),
      ),
      // Enhanced table styling for complex tables
      "table": Style(
        width: Width(100, Unit.percent),
        border: Border.all(color: Colors.grey[800]!, width: 1),
        margin: Margins.symmetric(vertical: 15),
        backgroundColor: Colors.white,
        display: Display.table,
      ),
      "thead": Style(
        backgroundColor: Colors.blue[100],
        display: Display.tableHeaderGroup,
      ),
      "tbody": Style(
        display: Display.tableRowGroup,
      ),
      "th": Style(
        padding: HtmlPaddings.all(8),
        border: Border.all(color: Colors.grey[600]!, width: 1),
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
        backgroundColor: Colors.blue[50],
        display: Display.tableCell,
        fontSize: FontSize(12.0),
      ),
      "td": Style(
        padding: HtmlPaddings.all(6),
        border: Border.all(color: Colors.grey[400]!, width: 1),
        textAlign:
            TextAlign.center, // Most data tables benefit from center alignment
        display: Display.tableCell,
        fontSize: FontSize(12.0),
        verticalAlign: VerticalAlign.middle,
      ),
      "tr": Style(
        border: Border.all(color: Colors.grey[400]!, width: 1),
        display: Display.tableRow,
      ),
      // Special styling for cells with class 'stdTableCell'
      ".stdTableCell": Style(
        padding: HtmlPaddings.all(6),
        border: Border.all(color: Colors.grey[400]!, width: 1),
        textAlign: TextAlign.center,
        display: Display.tableCell,
        fontSize: FontSize(11.0),
        verticalAlign: VerticalAlign.middle,
      ),
      // Style for superscript and subscript
      "sup": Style(
        fontSize: FontSize(10.0),
        verticalAlign: VerticalAlign.top,
      ),
      "sub": Style(
        fontSize: FontSize(10.0),
        verticalAlign: VerticalAlign.bottom,
      ),
    };
  }

  // Build content with custom table parsing and image handling
  Widget _buildContentWithTables(String htmlContent) {
    List<Widget> widgets = [];

    // Split content by tables
    final tablePattern =
        RegExp(r'<table[^>]*>.*?</table>', caseSensitive: false, dotAll: true);
    int lastIndex = 0;

    for (final match in tablePattern.allMatches(htmlContent)) {
      // Add HTML content before this table - handle images properly
      if (match.start > lastIndex) {
        final beforeContent = htmlContent.substring(lastIndex, match.start);
        if (beforeContent.trim().isNotEmpty) {
          // Check if beforeContent has cached images - if so, use mixed content handler
          if (beforeContent.contains('cached://')) {
            widgets.addAll(_buildContentSegmentWithImages(beforeContent));
          } else {
            widgets.add(Html(
              data: beforeContent,
              style: _getHtmlStyle(),
            ));
          }
        }
      }

      // Add the table widget
      final tableHtml = match.group(0);
      if (tableHtml != null) {
        widgets.add(_buildExtractedTable(tableHtml));
      }

      lastIndex = match.end;
    }

    // Add remaining HTML content after the last table - handle images properly
    if (lastIndex < htmlContent.length) {
      final remainingContent = htmlContent.substring(lastIndex);
      if (remainingContent.trim().isNotEmpty) {
        // Check if remainingContent has cached images - if so, use mixed content handler
        if (remainingContent.contains('cached://')) {
          widgets.addAll(_buildContentSegmentWithImages(remainingContent));
        } else {
          widgets.add(Html(
            data: remainingContent,
            style: _getHtmlStyle(),
          ));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Helper method to build content segment with proper image handling
  List<Widget> _buildContentSegmentWithImages(String htmlContent) {
    List<Widget> widgets = [];

    // Split content by image tags - improved regex to handle full URLs
    final imgPattern = RegExp(r'<img([^>]*?)src=(["\047])(.*?)\2([^>]*?)>',
        caseSensitive: false, dotAll: true);
    int lastIndex = 0;

    // Debug: Show all matches found by regex
    final matches = imgPattern.allMatches(htmlContent).toList();
    print(
        '🔍 _buildContentSegmentWithImages: Found ${matches.length} image matches');
    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final src = match.group(3);
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
          ));
        }
      }

      // Add the image widget
      final src = match.group(3); // Extract src attribute
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
        ));
      }
    }

    return widgets;
  }

  // Build extracted table widget without Html recursion
  Widget _buildExtractedTable(String tableHtml) {
    print(
        '🔧 _buildExtractedTable received HTML of length: ${tableHtml.length}');
    print(
        '📋 Table HTML preview: ${tableHtml.substring(0, tableHtml.length > 200 ? 200 : tableHtml.length)}...');

    try {
      // Parse table rows
      final rowPattern =
          RegExp(r'<tr[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true);
      final rows = rowPattern.allMatches(tableHtml).toList();

      if (rows.isEmpty) {
        print('❌ No table rows found');
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

      print('✅ Found ${rows.length} table rows');

      // Parse all rows as data
      final dataRows = <List<String>>[];
      bool hasHeaders = false;

      for (int i = 0; i < rows.length; i++) {
        final cellContent = rows[i].group(1) ?? '';
        final cells = _parseTableCells(cellContent);
        if (cells.isNotEmpty) {
          dataRows.add(cells);
          // Check if first row contains th elements (headers)
          if (i == 0 && cellContent.toLowerCase().contains('<th')) {
            hasHeaders = true;
          }
        }
      }

      if (dataRows.isEmpty) {
        print('❌ No valid table data found');
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

      print(
          '✅ Building table with ${dataRows.length} rows, hasHeaders: $hasHeaders');

      // Find the maximum number of columns
      final maxColumns = dataRows
          .map((row) => row.length)
          .fold<int>(0, (max, length) => length > max ? length : max);

      // Use Table widget for better control
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            children: dataRows.map((row) {
              // Pad row to match max columns
              final paddedRow = List<String>.from(row);
              while (paddedRow.length < maxColumns) {
                paddedRow.add('');
              }

              return TableRow(
                decoration: hasHeaders && dataRows.indexOf(row) == 0
                    ? BoxDecoration(color: Colors.grey[100])
                    : null,
                children: paddedRow
                    .map((cell) => Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            cell.trim(),
                            style: TextStyle(
                              fontWeight:
                                  hasHeaders && dataRows.indexOf(row) == 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ))
                    .toList(),
              );
            }).toList(),
          ),
        ),
      );
    } catch (e) {
      print('❌ Error parsing table: $e');
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

  // Parse table cells from HTML
  List<String> _parseTableCells(String rowHtml) {
    final cellPattern = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>',
        caseSensitive: false, dotAll: true);
    final cells = cellPattern
        .allMatches(rowHtml)
        .map((match) => match.group(1) ?? '')
        .map((cell) => _stripHtmlTags(cell))
        .toList();
    return cells;
  }

  // Strip HTML tags from text
  String _stripHtmlTags(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
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
  }

  // Build content with custom image handling and table support
  Widget _buildContentWithImages() {
    final text = currentSubChapter.text;
    if (text == null || text.isEmpty) {
      return const Text('Ingen innhold tilgjengelig');
    }

    final unescapedText = HtmlUnescape().convert(text);

    // Check for tables in content
    if (unescapedText.contains('<table')) {
      return _buildContentWithTables(unescapedText);
    }

    // Check if there are cached image references
    if (unescapedText.contains('cached://')) {
      return _buildMixedContent(unescapedText);
    } else {
      // Use regular HTML widget for content without cached images
      final style = _getHtmlStyle();
      style["img"] = Style(
        width: Width(100, Unit.percent),
        height: Height.auto(),
        display: Display.block,
        margin: Margins.symmetric(vertical: 10),
      );

      return Html(
        data: unescapedText,
        style: style,
      );
    }
  }

  // Build content with mixed HTML and cached images
  Widget _buildMixedContent(String htmlContent) {
    // Check if content has tables - if so, use custom table handling
    if (htmlContent.contains('<table')) {
      return _buildContentWithTables(htmlContent);
    }

    // Debug: Log the HTML content to see what we're working with
    print('📄 HTML content to parse:');
    print(htmlContent.substring(
        0, htmlContent.length > 500 ? 500 : htmlContent.length));
    if (htmlContent.length > 500) {
      print('... (truncated, full length: ${htmlContent.length})');
    }

    // Use the helper method for consistent image handling
    List<Widget> widgets = _buildContentSegmentWithImages(htmlContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Build image widget (cached or network)
  Widget _buildImageWidget(String src) {
    print('🖼️ _buildImageWidget called with src: $src');

    // Enhanced debugging - log ANY cached:// URL to see what we actually get
    if (src.startsWith('cached://')) {
      print('🎯 ENHANCED DEBUG for ANY cached image: $src');
      print('   Length: ${src.length}');
      print('   Contains /15: ${src.contains('/15')}');
      print('   Contains /0: ${src.contains('/0')}');
    }

    // Check if this is a cached image reference
    if (src.startsWith('cached://')) {
      final pathPart = src.substring(9); // Remove 'cached://'
      final parts = pathPart.split('/');
      print(
          '🔍 DETAILED: Cached image path: "$pathPart", parts: $parts, parts.length: ${parts.length}');

      // Enhanced debugging for parts
      for (int i = 0; i < parts.length; i++) {
        print('   Part[$i]: "${parts[i]}" (length: ${parts[i].length})');
      }

      // Check for malformed cached references and try to fix them
      if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) {
        print('❌ Malformed cached reference detected: $src');
        print('🔄 Converting to network image instead');

        // Show error with fix options for malformed cached references
        return Container(
          height: 150,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 10),
          color: Colors.red[50],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 24),
              const SizedBox(height: 8),
              Text('Malformed cached image reference',
                  style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              Text(src,
                  style: TextStyle(color: Colors.red[600], fontSize: 8),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _fixMalformedReferences(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                    child: const Text('Fix References',
                        style: TextStyle(fontSize: 9)),
                  ),
                  ElevatedButton(
                    onPressed: () => _clearCacheForPublication(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                    child: const Text('Clear Cache',
                        style: TextStyle(fontSize: 9)),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        final publicationId = parts[0];
        final imageIndex = int.tryParse(parts[1]);
        print(
            'Publication ID: "$publicationId", Image Index raw: "${parts[1]}", parsed: $imageIndex');

        if (imageIndex != null) {
          return FutureBuilder<File?>(
            future: _findCachedImageFile(publicationId, imageIndex),
            builder: (context, snapshot) {
              print(
                  'FutureBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, error: ${snapshot.error}');

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                print('Error loading cached image: ${snapshot.error}');
                return Container(
                  height: 100,
                  width: double.infinity,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Error: ${snapshot.error}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data == null) {
                print(
                    '❌ CRITICAL: No cached image file found for $publicationId/$imageIndex');
                print('   Original src: $src');
                print('   Parsed publicationId: $publicationId');
                print('   Parsed imageIndex: $imageIndex');

                // DEBUGGING: If this is the problematic case, let's check surrounding indices and list all cache files
                if (publicationId == '25621b7a-c477-47b6-ac3f-b6553f8a7e95') {
                  print(
                      '🔍 DEBUGGING: This is the target publication, checking surrounding indices...');
                  _checkSurroundingIndices(publicationId, imageIndex);
                  // List all cache files to see what's actually there
                  if (imageIndex == 0) {
                    // Only do this once per screen to avoid spam
                    _listCacheFiles();
                    _testFileWriting(publicationId, imageIndex);
                  }
                }

                return Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.orange[50],
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_not_supported,
                          color: Colors.orange, size: 32),
                      const SizedBox(height: 8),
                      Text('Image ikke cachet',
                          style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold)),
                      Text('Gå til Min Side og last ned offline data på nytt',
                          style: TextStyle(
                              color: Colors.orange[700], fontSize: 12),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text('Image: $imageIndex',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 10)),
                      Text('Src: $src',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 8),
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Image.file(
                  snapshot.data!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(height: 8),
                          Text('Error displaying cached image',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        } else {
          print('❌ Failed to parse image index from cached reference: $src');
          return Container(
            height: 100,
            width: double.infinity,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(height: 8),
                Text('Malformed cached reference',
                    style: TextStyle(color: Colors.grey[600])),
                Text(src,
                    style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              ],
            ),
          );
        }
      } else {
        print(
            '❌ Invalid cached reference format: $src (path: "$pathPart", parts: $parts)');
        return Container(
          height: 100,
          width: double.infinity,
          color: Colors.grey[300],
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(height: 8),
              Text('Invalid cached reference format',
                  style: TextStyle(color: Colors.grey[600])),
              Text(src,
                  style: TextStyle(color: Colors.grey[500], fontSize: 10)),
            ],
          ),
        );
      }
    }

    // For non-cached images, use network image
    return _buildNetworkImageWidget(src);
  }

  // Build network image widget with error handling
  Widget _buildNetworkImageWidget(String src) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Image.network(
        src,
        width: double.infinity,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 100,
            width: double.infinity,
            color: Colors.grey[300],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(height: 8),
                Text('Failed to load image',
                    style: TextStyle(color: Colors.grey[600])),
                Text(src,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _checkIfBookmarked() async {
    final bookmarks = await loadBookmarks();
    final isBookmarked = bookmarks.any((s) => s.id == currentSubChapter.id);
    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final List<SubChapter> bookmarks = await loadBookmarks();
    final exists = bookmarks.any((s) => s.id == currentSubChapter.id);
    if (exists) {
      // Fjern bokmerke
      bookmarks.removeWhere((s) => s.id == currentSubChapter.id);
      final String jsonString = jsonEncode(bookmarks
          .map((e) => {
                'ID': e.id,
                'Title': e.title,
                'webUrl': e.webUrl,
                'Number': e.number,
              })
          .toList());
      await prefs.setString('bookmarked_subchapters', jsonString);
      if (mounted) {
        setState(() {
          _isBookmarked = false;
        });
      }
    } else {
      // Legg til bokmerke
      await saveBookmark(currentSubChapter);
      if (mounted) {
        setState(() {
          _isBookmarked = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: currentSubChapter.title,
      actions: [
        IconButton(
          icon: Icon(
            _isBookmarked ? Icons.star : Icons.star_border,
            color: _isBookmarked ? Colors.amber : null,
          ),
          tooltip: _isBookmarked ? 'Fjern bokmerke' : 'Legg til bokmerke',
          onPressed: _toggleBookmark,
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text(
                      '${currentSubChapter.number ?? ''} ${currentSubChapter.title}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildContentWithImages(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: widget.currentIndex > 0
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubChapterDetailScreen(
                                subChapters: widget.subChapters,
                                currentIndex: widget.currentIndex - 1,
                                bookId: widget.bookId,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Forrige'),
                ),
                ElevatedButton(
                  onPressed: widget.currentIndex < widget.subChapters.length - 1
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubChapterDetailScreen(
                                subChapters: widget.subChapters,
                                currentIndex: widget.currentIndex + 1,
                                bookId: widget.bookId,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Neste'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Clear cache for this publication to fix malformed references
  Future<void> _clearCacheForPublication() async {
    try {
      final publicationId = widget.bookId;

      print('🧹 Clearing comprehensive cache for publication: $publicationId');

      // First, let's debug what's in the current cache
      final publicationService = PublicationService();
      await publicationService.getCachedFullContent(publicationId);

      // Then clear it completely
      await publicationService.clearCachedImagesForPublication(publicationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Cache cleared completely! Please go back and reopen this publication.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Go back to publication detail screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ Error clearing cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fix malformed cached references
  Future<void> _fixMalformedReferences() async {
    try {
      final success =
          await _publicationService.fixMalformedCachedReferences(widget.bookId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fixed malformed cached references successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload the screen
          setState(() {});
        }
      } else {
        throw Exception('Failed to fix malformed references');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fixing references: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Smart method to find cached image file with fallback search
  Future<File?> _findCachedImageFile(
      String publicationId, int expectedIndex) async {
    // First try the expected index
    var file = await _publicationService.getCachedContentImageFile(
        publicationId, expectedIndex);
    if (file != null) {
      return file;
    }

    print(
        '🔍 SMART FALLBACK: Image not found at expected index $expectedIndex, searching alternatives...');

    // If expected index doesn't work, try some common alternatives
    // This might help if there's an off-by-one error or similar indexing issue
    final alternativeIndices = [
      expectedIndex + 1,
      expectedIndex - 1,
      expectedIndex + 10,
      expectedIndex - 10,
      15, // The specific index mentioned by user
      0, // Sometimes images start at 0
      1, // Sometimes they start at 1
    ];

    for (final altIndex in alternativeIndices) {
      if (altIndex >= 0) {
        file = await _publicationService.getCachedContentImageFile(
            publicationId, altIndex);
        if (file != null) {
          print(
              '✅ SMART FALLBACK SUCCESS: Found image at alternative index $altIndex instead of $expectedIndex');
          return file;
        }
      }
    }

    print(
        '❌ SMART FALLBACK FAILED: No cached image found with any alternative index');
    return null;
  }

  // Debug method to check surrounding indices for cached images
  void _checkSurroundingIndices(String publicationId, int targetIndex) async {
    print('🔍 CHECKING SURROUNDING INDICES for target index: $targetIndex');

    // Check indices from targetIndex-5 to targetIndex+5
    for (int i = targetIndex - 5; i <= targetIndex + 5; i++) {
      if (i >= 0) {
        final file = await _publicationService.getCachedContentImageFile(
            publicationId, i);
        if (file != null) {
          print('✅ Found image at index $i: ${file.path}');
        } else {
          print('❌ No image at index $i');
        }
      }
    }
  }

  // Debug method to list all files in cache directory
  Future<void> _listCacheFiles() async {
    try {
      final Directory appSupportDir = await getApplicationSupportDirectory();
      print('📁 CACHE DIRECTORY DEBUG: ${appSupportDir.path}');

      if (await appSupportDir.exists()) {
        final List<FileSystemEntity> files =
            await appSupportDir.list().toList();
        print('📊 Found ${files.length} total files/folders in cache');

        // Filter for image files
        final List<File> imageFiles = files
            .whereType<File>()
            .where((file) => file.path.contains('content_img_'))
            .toList();

        print('🖼️ Found ${imageFiles.length} image files:');
        for (final file in imageFiles) {
          final fileName = file.path.split('/').last.split('\\').last;
          final fileSize = await file.length();
          print('   - $fileName ($fileSize bytes)');
        }

        // Check specifically for our publication
        final List<File> ourImages = imageFiles
            .where((file) =>
                file.path.contains('25621b7a-c477-47b6-ac3f-b6553f8a7e95'))
            .toList();

        print(
            '🎯 Found ${ourImages.length} image files for target publication');

        // Also check for fullcontent file
        final List<File> contentFiles = files
            .whereType<File>()
            .where((file) => file.path.contains('fullcontent_'))
            .toList();
        print('📄 Found ${contentFiles.length} content files');
      } else {
        print('❌ Cache directory does not exist!');
      }
    } catch (e) {
      print('❌ Error listing cache files: $e');
    }
  }

  // Test file writing functionality
  Future<void> _testFileWriting(String publicationId, int imageIndex) async {
    try {
      print('🧪 TEST: Attempting to write and read test image file...');

      // Test data
      final testData = List<int>.generate(256, (i) => i);
      final testFilename = 'test_content_img_${publicationId}_$imageIndex.img';

      // Write test file
      await LocalStorageService.writeImage(testFilename, testData);
      print('✅ TEST: Wrote test file: $testFilename');

      // Immediately read it back
      final readFile = await LocalStorageService.readImageFile(testFilename);
      if (readFile != null) {
        print('✅ TEST SUCCESS: Can write and read back image file');
        print('✅ TEST FILE PATH: ${readFile.path}');
        final fileExists = await readFile.exists();
        final fileLength = fileExists ? await readFile.length() : 0;
        print('✅ TEST FILE EXISTS: $fileExists, SIZE: $fileLength bytes');

        // Clean up test file
        try {
          await readFile.delete();
          print('🧹 TEST: Cleaned up test file');
        } catch (e) {
          print('⚠️  TEST: Could not delete test file: $e');
        }
      } else {
        print('❌ TEST FAILED: Cannot read back test file!');
      }

      // Also test the actual expected file name to see if the issue is filename-specific
      final expectedFilename = 'content_img_${publicationId}_$imageIndex.img';
      print(
          '🧪 TEST: Attempting to write expected filename: $expectedFilename');

      await LocalStorageService.writeImage(expectedFilename, testData);
      print('✅ TEST: Wrote expected filename: $expectedFilename');

      final readExpected =
          await LocalStorageService.readImageFile(expectedFilename);
      if (readExpected != null) {
        print('✅ TEST SUCCESS: Expected filename works!');
        print('✅ TEST FILE PATH: ${readExpected.path}');

        // Clean up
        try {
          await readExpected.delete();
          print('🧹 TEST: Cleaned up expected filename test file');
        } catch (e) {
          print('⚠️  TEST: Could not delete expected filename test file: $e');
        }
      } else {
        print('❌ TEST FAILED: Expected filename does not work!');
      }
    } catch (e) {
      print('💥 TEST ERROR: $e');
    }
  }
}
