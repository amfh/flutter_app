import 'package:flutter/material.dart';
import 'package:flutter_app/screens/search_results_screen.dart';
import '../services/publication_service.dart';
import '../models/subchapter.dart';
import '../models/publication.dart';
import 'search_results_screen.dart';

class SubchapterSearchBar extends StatefulWidget {
  const SubchapterSearchBar({super.key});

  @override
  State<SubchapterSearchBar> createState() => _SubchapterSearchBarState();
}

class _SubchapterSearchBarState extends State<SubchapterSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isSearching = false;
  List<Publication> _publications = [];
  Publication? _selectedPublication; // null = alle

  @override
  void initState() {
    super.initState();
    _loadPublications();
  }

  Future<void> _loadPublications() async {
    final service = PublicationService();
    final pubs = await service.loadPublications();
    setState(() {
      _publications = pubs;
    });
  }

  Future<List<SubChapter>> _search(String query) async {
    final service = PublicationService();
    final List<SubChapter> all = [];
    final pubs = _selectedPublication == null
        ? await service.loadPublications()
        : [_selectedPublication!];
    for (final pub in pubs) {
      final hasCache = await service.hasFullContentCache(pub.id);
      if (!hasCache) continue;
      try {
        final chapters = await service.fetchChapters(pub.id);
        for (final chapter in chapters) {
          final subs = await service.fetchSubChapters(chapter.id, pub.id);
          all.addAll(subs);
        }
      } catch (_) {}
    }
    // Lynraskt søk kun i tittel
    final lowerQuery = query.toLowerCase();
    final titleMatches =
        all.where((s) => s.title.toLowerCase().contains(lowerQuery)).toList();
    return titleMatches;
  }

  void _onSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final results = await _search(query);
    setState(() => _isSearching = false);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          query: query,
          results: results,
          enableTextSearch: true,
          allSubChapters: results, // for utvidet søk
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Søk i underkapitler...',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onSubmitted: (_) => _onSearch(),
          ),
        ),
        const SizedBox(width: 8),
        _isSearching
            ? const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.search),
                onPressed: _onSearch,
              ),
      ],
    );
  }
}
