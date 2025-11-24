import 'package:flutter/material.dart';
import '../models/user_data.dart';
import '../models/new_publication.dart';
import '../services/new_user_data_service.dart';
import '../services/new_publication_service.dart';
import '../widgets/new_main_scaffold.dart';
import 'new_subchapter_detail_screen.dart';

class NewBookmarksScreen extends StatefulWidget {
  const NewBookmarksScreen({super.key});

  @override
  State<NewBookmarksScreen> createState() => _NewBookmarksScreenState();
}

class _NewBookmarksScreenState extends State<NewBookmarksScreen> {
  late Future<List<BookmarkedSubchapter>> _bookmarksFuture;

  @override
  void initState() {
    super.initState();
    _bookmarksFuture = _loadBookmarks();
  }

  Future<List<BookmarkedSubchapter>> _loadBookmarks() async {
    try {
      final userData = await UserDataService.instance.loadUserData();
      return userData?.bookmarks ?? [];
    } catch (e) {
      print('❌ Error loading bookmarks: $e');
      return [];
    }
  }

  Future<void> _removeBookmark(BookmarkedSubchapter bookmark) async {
    try {
      final userDataService = UserDataService.instance;
      final userData = await userDataService.loadUserData();

      if (userData == null) return;

      final bookmarks = List<BookmarkedSubchapter>.from(userData.bookmarks);
      bookmarks.removeWhere((b) => b.id == bookmark.id);

      final updatedUserData = UserData(
        email: userData.email,
        subscriptions: userData.subscriptions,
        availablePublications: userData.availablePublications,
        bookmarks: bookmarks,
        lastUpdated: DateTime.now(),
      );

      await userDataService.saveUserData(updatedUserData);

      setState(() {
        _bookmarksFuture = _loadBookmarks();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bokmerke fjernet')),
        );
      }
    } catch (e) {
      print('❌ Error removing bookmark: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunne ikke fjerne bokmerke')),
        );
      }
    }
  }

  Future<void> _openBookmark(BookmarkedSubchapter bookmark) async {
    try {
      // Load publication content to find the correct chapter and subchapter
      final chapters = await NewPublicationService.instance
          .loadPublicationContent(bookmark.publicationId);

      if (chapters == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Kunne ikke laste publikasjonsinnhold')),
          );
        }
        return;
      }

      // Create a minimal publication object from bookmark data
      // No need to fetch from API since we have all needed info
      final publication = Publication(
        id: bookmark.publicationId,
        name: bookmark.publicationName,
        imageUrl: '',
        restrictPublicAccessIds: [],
        createDate: DateTime.now(),
        updateDate: DateTime.now(),
      );

      // Find the matching chapter and subchapter
      for (final chapter in chapters) {
        if (chapter.title == bookmark.chapterTitle) {
          for (int i = 0; i < chapter.subchapters.length; i++) {
            final subchapter = chapter.subchapters[i];
            if (subchapter.title == bookmark.subchapterTitle) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewSubchapterDetailScreen(
                      publication: publication,
                      chapter: chapter,
                      subchapter: subchapter,
                      allSubchapters: chapter.subchapters,
                      currentIndex: i,
                    ),
                  ),
                );
              }
              return;
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunne ikke finne bokmerket innhold')),
        );
      }
    } catch (e) {
      print('❌ Error opening bookmark: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunne ikke åpne bokmerke')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NewMainScaffold(
      title: 'Bokmerker',
      currentRoute: '/bookmarks',
      child: FutureBuilder<List<BookmarkedSubchapter>>(
        future: _bookmarksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Feil: ${snapshot.error}'),
                ],
              ),
            );
          }

          final bookmarks = snapshot.data ?? [];

          if (bookmarks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Ingen bokmerker',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trykk på stjerne-ikonet i et underkapittel\nfor å legge til et bokmerke',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.star,
                    color: Colors.yellow[700],
                    size: 32,
                  ),
                  title: Text(
                    bookmark.subchapterNumber != null
                        ? '${bookmark.subchapterNumber} ${bookmark.subchapterTitle}'
                        : bookmark.subchapterTitle,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        bookmark.publicationName,
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        bookmark.chapterTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Fjern bokmerke',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Fjern bokmerke'),
                          content: Text(
                            'Er du sikker på at du vil fjerne bokmerket for "${bookmark.subchapterTitle}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Avbryt'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Fjern'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await _removeBookmark(bookmark);
                      }
                    },
                  ),
                  onTap: () => _openBookmark(bookmark),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
