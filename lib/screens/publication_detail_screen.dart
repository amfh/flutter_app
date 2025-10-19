import 'package:flutter/material.dart';
import '../models/publication.dart';
import '../models/chapter.dart';
import '../services/publication_service.dart';
import 'subchapter_list_screen.dart';
import '../widgets/main_scaffold.dart';
import '../services/local_storage_service.dart';

class PublicationDetailScreen extends StatefulWidget {
  final Publication publication;

  const PublicationDetailScreen({super.key, required this.publication});

  @override
  State<PublicationDetailScreen> createState() =>
      _PublicationDetailScreenState();
}

class _PublicationDetailScreenState extends State<PublicationDetailScreen> {
  Future<void> _deleteCachedData() async {
    final filename = 'fullcontent_${widget.publication.id}.json';
    await LocalStorageService.clearFile(filename);
    if (mounted) {
      setState(() {
        _chapters = Future.value([]);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lagret data slettet.')),
      );
    }
  }

  Future<void> _clearMalformedCache(String publicationId) async {
    try {
      final filename = 'fullcontent_$publicationId.json';
      await LocalStorageService.clearFile(filename);
      print('🧹 Cleared malformed cached data: $filename');
    } catch (e) {
      print('❌ Error clearing malformed cache: $e');
    }
  }

  final PublicationService _service = PublicationService();
  late Future<List<Chapter>> _chapters = Future.value([]);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    // Only check if cached data exists - don't download automatically
    final hasCache = await _service.hasFullContentCache(widget.publication.id);

    if (hasCache) {
      // Check if cached data contains malformed references
      try {
        final cachedData =
            await _service.getCachedFullContent(widget.publication.id);
        if (cachedData != null) {
          final dataString = cachedData.toString();
          // Look for malformed cached references - any cached:// that doesn't have proper format
          final malformedPattern =
              RegExp(r'cached://[a-zA-Z0-9]{4,12}(?![a-zA-Z0-9-]{25,}/\d+)');
          final allCachedRefs =
              RegExp(r'cached://[^"\s>]+').allMatches(dataString);

          print('📊 Found ${allCachedRefs.length} cached references in data');
          for (final match in allCachedRefs) {
            print('🔍 Cached ref: ${match.group(0)}');
          }

          if (malformedPattern.hasMatch(dataString)) {
            print(
                '🚨 Detected malformed cached references - clearing cache for publication ${widget.publication.id}');
            // Clear the malformed cached data
            await _clearMalformedCache(widget.publication.id);
            // Show empty state after clearing malformed cache
            setState(() {
              _chapters = Future.value([]);
              _isLoading = false;
            });
            return;
          } else {
            print('✅ All cached references appear to be properly formatted');
          }
        }
      } catch (e) {
        print('Error checking cached data: $e');
        // Show empty state if there's an error with cached data
        setState(() {
          _chapters = Future.value([]);
          _isLoading = false;
        });
        return;
      }

      // Use cached data
      print('Using cached data for publication ${widget.publication.id}');
      setState(() {
        _chapters = _service.fetchChapters(widget.publication.id);
        _isLoading = false;
      });
    } else {
      // No cached data - don't download, just show empty state
      print(
          'No cached data for publication ${widget.publication.id} - user needs to download from Min Side');
      setState(() {
        _chapters = Future.value([]);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: widget.publication.title,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Slett lagret data',
          onPressed: _deleteCachedData,
        ),
      ],
      body: _isLoading
          ? Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Laster ned publikasjonsdata',
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.publication.imageUrl.isNotEmpty)
                  Image.network(
                    "https://kompetansebiblioteket.no${widget.publication.imageUrl}",
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 100),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.publication.ingress,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Kapitler",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Chapter>>(
                    future: _chapters,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Feil: ${snapshot.error}'));
                      }
                      final chapters = snapshot.data ?? [];
                      if (chapters.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.download_for_offline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Publikasjon ikke lastet ned',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Gå til Min Side og last ned offline data for å se innholdet i denne publikasjonen.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = chapters[index];
                          return ListTile(
                            leading: const Icon(Icons.menu_book),
                            title: Text(chapter.title),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubChapterListScreen(
                                    chapter: chapter,
                                    publicationId: widget.publication.id,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
