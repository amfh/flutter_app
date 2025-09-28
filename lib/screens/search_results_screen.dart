import 'package:flutter/material.dart';
import '../services/publication_service.dart';
import '../models/subchapter.dart';
import '../models/publication.dart';
import 'subchapter_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;
  final List<SubChapter> results;
  final bool enableTextSearch;
  final List<SubChapter>? allSubChapters;
  const SearchResultsScreen({
    super.key,
    required this.query,
    required this.results,
    this.enableTextSearch = false,
    this.allSubChapters,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  List<Publication> _publications = [];
  Publication? _selectedPublication;
  List<SubChapter> _filteredResults = [];

  @override
  void initState() {
    super.initState();
    _filteredResults = widget.results;
    _loadPublications();
  }

  Future<void> _loadPublications() async {
    final service = PublicationService();
    final pubs = await service.loadPublications();
    setState(() {
      _publications = pubs;
    });
  }

  Future<void> _filterResults(Publication? pub) async {
    setState(() {
      _selectedPublication = pub;
    });
    if (pub == null) {
      setState(() {
        _filteredResults = widget.results;
      });
      return;
    }
    // Filter subchapters by publication
    final service = PublicationService();
    final hasCache = await service.hasFullContentCache(pub.id);
    if (!hasCache) {
      setState(() {
        _filteredResults = [];
      });
      return;
    }
    final chapters = await service.fetchChapters(pub.id);
    final chapterIds = chapters.map((c) => c.id).toSet();
    setState(() {
      _filteredResults = widget.results
          .where((s) => chapterIds.contains(s.id.split('-').first))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Søkeresultater'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<Publication?>(
                    value: _selectedPublication,
                    hint: const Text('Filtrer på publikasjon'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<Publication?>(
                        value: null,
                        child: Text('Alle publikasjoner'),
                      ),
                      ..._publications
                          .map((pub) => DropdownMenuItem<Publication?>(
                                value: pub,
                                child: Text(pub.title),
                              )),
                    ],
                    onChanged: (val) {
                      _filterResults(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.enableTextSearch &&
              widget.results.isEmpty &&
              widget.allSubChapters != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.manage_search),
                label: const Text('Søk også i tekstinnhold'),
                onPressed: () async {
                  final service = PublicationService();
                  final lowerQuery = widget.query.toLowerCase();
                  final List<SubChapter> textMatches = [];
                  for (final sub in widget.allSubChapters!) {
                    try {
                      final detail =
                          await service.fetchSubChapterDetail(sub.id);
                      if ((detail.text ?? '')
                          .toLowerCase()
                          .contains(lowerQuery)) {
                        textMatches.add(sub);
                      }
                    } catch (_) {}
                  }
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchResultsScreen(
                          query: widget.query,
                          results: textMatches,
                          enableTextSearch: false,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          Expanded(
            child: _filteredResults.isEmpty
                ? Center(child: Text('Ingen treff for "${widget.query}".'))
                : ListView.builder(
                    itemCount: _filteredResults.length,
                    itemBuilder: (context, index) {
                      final sub = _filteredResults[index];
                      return ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: Text(sub.title),
                        subtitle: Text(
                          sub.webUrl ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubChapterDetailScreen(
                                subChapters: _filteredResults,
                                currentIndex: index,
                                bookId: '',
                              ),
                            ),
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
