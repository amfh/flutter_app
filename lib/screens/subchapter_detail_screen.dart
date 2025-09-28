import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/subchapter.dart';
import '../models/subchapter_detail.dart';
import '../services/publication_service.dart';
import '../widgets/main_scaffold.dart';
import '../services/subchapter_offline_helper.dart';

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
  late Future<SubChapterDetail> _detailFuture;
  final PublicationService _service = PublicationService();

  String get _bookId => widget.bookId;

  SubChapter get currentSubChapter => widget.subChapters[widget.currentIndex];

  bool _isBookmarked = false;

  Future<SubChapterDetail> _loadDetail() async {
    // Prøv offline først hvis bookId er kjent
    final bookId = _bookId;
    final offline =
        await getOfflineSubChapterDetail(bookId, currentSubChapter.id);
    if (offline != null) return offline;
    // Faller tilbake til API hvis ikke funnet offline
    return await _service.fetchSubChapterDetail(currentSubChapter.id);
  }

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
    _checkIfBookmarked();
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
      body: FutureBuilder<SubChapterDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Feil: \\${snapshot.error}'));
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('Ingen data'));
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      Text('${detail.number ?? ''} ${detail.title}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Html(
                          data: detail.text != null
                              ? HtmlUnescape().convert(detail.text!)
                              : ''),
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
                      onPressed:
                          widget.currentIndex < widget.subChapters.length - 1
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
          );
        },
      ),
    );
  }
}
