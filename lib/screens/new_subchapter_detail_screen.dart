import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/new_publication.dart';
import '../services/new_publication_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUpdatedContent();
  }

  Future<void> _loadUpdatedContent() async {
    try {
      // Load the updated content from local storage that might have cached:// references
      final updatedSubchapter = await _getUpdatedSubchapterContent();

      setState(() {
        _updatedContent = updatedSubchapter?.text ?? widget.subchapter.text;
        _isLoading = false;
      });
    } catch (e) {
      // Error loading updated content
      setState(() {
        _updatedContent = widget.subchapter.text;
        _isLoading = false;
      });
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
            icon: const Icon(Icons.share),
            onPressed: () => _shareContent(context),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: _buildBody(context),
      bottomNavigationBar: _buildFloatingNavigationBar(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          16.0, 16.0, 16.0, 100.0), // Extra bottom padding for floating bar
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subchapter header
          _buildHeader(),
          const SizedBox(height: 24),

          // Content
          _buildContent(context),
        ],
      ),
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
    return _buildContentWithTables(
        _updatedContent ?? widget.subchapter.text, context);
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

  // Build extracted table widget
  Widget _buildExtractedTable(String tableHtml) {
    try {
      print('📊 DEBUG: Building table from HTML...');
      print('📊 DEBUG: Table HTML length: ${tableHtml.length}');

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
    print('📊 DEBUG: Parsing table cells from: $rowHtml');
    final cellPattern = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>',
        caseSensitive: false, dotAll: true);
    final cells = cellPattern
        .allMatches(rowHtml)
        .map((match) => match.group(1) ?? '')
        .map((cell) => _stripHtmlTags(cell))
        .toList();
    print('📊 DEBUG: Parsed cells: $cells');
    return cells;
  }

  // Strip HTML tags from text
  String _stripHtmlTags(String htmlText) {
    print('📊 DEBUG: Stripping HTML from: "$htmlText"');
    final result = htmlText
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
    print('📊 DEBUG: Stripped result: "$result"');
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
    };
  }

  void _handleLinkTap(String? url, BuildContext context) {
    if (url == null) return;

    // For now, just show the URL
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

      // If it's already a cached:// URL, extract the index
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

      // For network URLs, we need to find which cached file corresponds to this URL
      // This requires loading the publication content and finding the image's position
      return await _findCachedImageByUrl(imageUrl);
    } catch (e) {
      print('❌ Error finding cached image: $e');
      return null;
    }
  }

  // Find cached image by matching URL in publication content
  Future<File?> _findCachedImageByUrl(String targetUrl) async {
    try {
      // Get all image URLs from the publication content
      final allImageUrls = await _getAllImageUrlsFromPublication();

      // Find the index of this URL
      final index = allImageUrls.indexOf(targetUrl);
      if (index >= 0) {
        print('🎯 Found target URL at index $index: $targetUrl');
        return await NewPublicationService.instance
            .getCachedImageFile(widget.publication.id, index);
      }

      print(
          '❓ URL not found in publication content, trying smart fallback: $targetUrl');
      return await _smartImageSearch(targetUrl);
    } catch (e) {
      print('❌ Error in _findCachedImageByUrl: $e');
      return null;
    }
  }

  // Get all image URLs from publication content
  Future<List<String>> _getAllImageUrlsFromPublication() async {
    try {
      final chapters = await NewPublicationService.instance
          .loadPublicationContent(widget.publication.id);
      final imageUrls = <String>[];

      if (chapters != null) {
        for (final chapter in chapters) {
          for (final subchapter in chapter.subchapters) {
            final urls = _extractImageUrlsFromHtml(subchapter.text);
            imageUrls.addAll(urls);
          }
        }
      }

      return imageUrls;
    } catch (e) {
      print('❌ Error getting image URLs: $e');
      return [];
    }
  }

  // Extract image URLs from HTML content
  List<String> _extractImageUrlsFromHtml(String htmlContent) {
    final imageUrls = <String>[];
    final imgPattern = RegExp(r'<img[^>]+src=(["\047])([^"\047]+)\1[^>]*>',
        caseSensitive: false);

    for (final match in imgPattern.allMatches(htmlContent)) {
      final src = match.group(2);
      if (src != null &&
          src.isNotEmpty &&
          !src.startsWith('cached://') &&
          !src.startsWith('file://')) {
        imageUrls.add(src);
      } else if (src != null && src.startsWith('file://')) {
        print('🔍 Found file:// image in content: $src');
      }
    }

    return imageUrls;
  }

  // Smart search for images (similar to old implementation)
  Future<File?> _smartImageSearch(String targetUrl) async {
    // Try different indices to find any available image
    for (int i = 0; i < 50; i++) {
      // Check up to 50 images
      final file = await NewPublicationService.instance
          .getCachedImageFile(widget.publication.id, i);
      if (file != null) {
        print('✅ Smart fallback found image at index $i');
        return file;
      }
    }

    print('❌ No images found in smart search');
    return null;
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
