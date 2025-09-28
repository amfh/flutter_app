import 'package:flutter/material.dart';
import '../models/publication.dart';
import '../models/chapter.dart';
import '../services/publication_service.dart';
import 'subchapter_list_screen.dart';
import '../widgets/main_scaffold.dart';
import '../services/local_storage_service.dart';
import '../widgets/internet_status_helper.dart';

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

  final PublicationService _service = PublicationService();
  late Future<List<Chapter>> _chapters = Future.value([]);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    // Sjekk om fullcontent allerede er cachet
    final hasCache = await _service.hasFullContentCache(widget.publication.id);
    if (hasCache) {
      setState(() {
        _chapters = _service.fetchChapters(widget.publication.id);
        _isLoading = false;
      });
    } else {
      setState(() {
        _chapters = _service.fetchChapters(widget.publication.id);
        _isLoading = true;
      });
      try {
        await _service.downloadAndCacheFullContent(widget.publication.id);
        setState(() {
          _chapters = _service.fetchChapters(widget.publication.id);
          _isLoading = false;
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          final hasInternet = await hasInternetConnection();
          if (!hasInternet) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Ingen internettforbindelse'),
                content: const Text(
                    'Du må ha internett for å laste ned denne publikasjonen.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Feil ved nedlasting: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MainScaffold(
          title: widget.publication.title,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Slett lagret data',
              onPressed: _deleteCachedData,
            ),
          ],
          body: Column(
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
                      return const Center(child: Text('Ingen kapitler funnet'));
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
        ),
        if (_isLoading)
          Container(
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
          ),
      ],
    );
  }
}
