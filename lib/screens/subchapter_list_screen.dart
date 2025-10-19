import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../models/subchapter.dart';
import '../services/publication_service.dart';
import 'subchapter_detail_screen.dart';
import '../widgets/main_scaffold.dart';

class SubChapterListScreen extends StatefulWidget {
  final Chapter chapter;
  final String publicationId;
  const SubChapterListScreen(
      {super.key, required this.chapter, required this.publicationId});

  @override
  State<SubChapterListScreen> createState() => _SubChapterListScreenState();
}

class _SubChapterListScreenState extends State<SubChapterListScreen> {
  late Future<List<SubChapter>> _subChapters = Future.value([]);
  final PublicationService _service = PublicationService();

  @override
  void initState() {
    super.initState();
    _waitForFullContentAndLoad();
  }

  Future<void> _waitForFullContentAndLoad() async {
    // Prøv å vente på at fullcontent-filen finnes, maks 2 sekunder
    for (int i = 0; i < 10; i++) {
      final hasCache = await _service.hasFullContentCache(widget.publicationId);
      if (hasCache) {
        setState(() {
          _subChapters = _service.fetchSubChapters(
              widget.chapter.id, widget.publicationId);
        });
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    // Hvis ikke funnet, vis tom liste (eller evt. feilmelding)
    setState(() {
      _subChapters = Future.error(
          'Ingen lagret fullcontent-data for denne publikasjonen. Prøv å åpne publikasjonen på nytt først.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: widget.chapter.title,
      body: FutureBuilder<List<SubChapter>>(
        future: _subChapters,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Feil: \\${snapshot.error}\n\nStacktrace:\n\\${snapshot.stackTrace}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            );
          }
          final subChapters = snapshot.data ?? [];
          if (subChapters.isEmpty) {
            return const Center(child: Text('Ingen underkapitler funnet'));
          }
          return ListView.builder(
            itemCount: subChapters.length,
            itemBuilder: (context, index) {
              final sub = subChapters[index];
              return ListTile(
                leading: const Icon(Icons.pages_outlined),
                title: Text('${sub.number ?? ''} ${sub.title}'),
                subtitle: Text(sub.webUrl ?? 'Ingen lenke'),
                onTap: () {
                  // Pass på at alle subChapters har riktig bookId
                  final withBookId = subChapters
                      .map((s) => s.bookId == null || s.bookId == ''
                          ? SubChapter(
                              id: s.id,
                              title: s.title,
                              webUrl: s.webUrl,
                              number: s.number,
                              bookId: widget.publicationId,
                              text: s.text,
                            )
                          : s)
                      .toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubChapterDetailScreen(
                        subChapters: withBookId,
                        currentIndex: index,
                        bookId: widget.publicationId,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
