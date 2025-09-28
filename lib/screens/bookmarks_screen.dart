import 'package:flutter/material.dart';
import '../models/subchapter.dart';
import 'subchapter_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/main_scaffold.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  Future<void> _removeBookmark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('bookmarked_subchapters');
    if (jsonString == null) return;
    final List<dynamic> data = jsonDecode(jsonString);
    data.removeWhere((e) => (e['ID'] ?? e['id']) == id);
    await prefs.setString('bookmarked_subchapters', jsonEncode(data));
    setState(() {
      _bookmarksFuture = _loadBookmarks();
    });
  }

  late Future<List<SubChapter>> _bookmarksFuture;

  @override
  void initState() {
    super.initState();
    _bookmarksFuture = _loadBookmarks();
  }

  Future<List<SubChapter>> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('bookmarked_subchapters');
    if (jsonString == null) return [];
    final List<dynamic> data = jsonDecode(jsonString);
    return data.map((e) => SubChapter.fromJson(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Bokmerker',
      body: FutureBuilder<List<SubChapter>>(
        future: _bookmarksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Feil: \\${snapshot.error}'));
          }
          final bookmarks = snapshot.data ?? [];
          if (bookmarks.isEmpty) {
            return const Center(child: Text('Ingen bokmerker'));
          }
          return ListView.builder(
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final sub = bookmarks[index];
              return ListTile(
                title: Text('${sub.number ?? ''} ${sub.title}'),
                subtitle: Text(sub.webUrl ?? ''),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubChapterDetailScreen(
                        subChapters: [sub],
                        currentIndex: 0,
                        bookId: sub.bookId ?? '',
                      ),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Slett bokmerke',
                  onPressed: () async {
                    await _removeBookmark(sub.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
