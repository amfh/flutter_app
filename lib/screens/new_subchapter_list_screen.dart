import 'package:flutter/material.dart';
import '../models/new_publication.dart';
import 'new_subchapter_detail_screen.dart';

class NewSubchapterListScreen extends StatelessWidget {
  final Publication publication;
  final Chapter chapter;

  const NewSubchapterListScreen({
    super.key,
    required this.publication,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(chapter.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (chapter.subchapters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Ingen underkapitler funnet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dette kapittelet inneholder ingen underkapitler.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Chapter header with abstract if available
        if (chapter.abstract != null && chapter.abstract!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sammendrag',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  chapter.abstract!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),

        // List of subchapters
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: chapter.subchapters.length,
            itemBuilder: (context, index) {
              final subchapter = chapter.subchapters[index];
              return _buildSubchapterCard(context, subchapter, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubchapterCard(
      BuildContext context, Subchapter subchapter, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          subchapter.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subchapter.number != null && subchapter.number!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Avsnitt ${subchapter.number}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.description,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _getContentLength(subchapter.text),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => _openSubchapter(context, subchapter),
      ),
    );
  }

  String _getContentLength(String text) {
    // Remove HTML tags for a rough word count
    final plainText = text.replaceAll(RegExp(r'<[^>]*>'), '');
    final wordCount = plainText.trim().split(RegExp(r'\s+')).length;

    if (wordCount < 100) {
      return 'Kort innhold';
    } else if (wordCount < 500) {
      return 'Middels innhold';
    } else {
      return 'Langt innhold';
    }
  }

  void _openSubchapter(BuildContext context, Subchapter subchapter) {
    // Find the current index of this subchapter
    final currentIndex = chapter.subchapters.indexOf(subchapter);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewSubchapterDetailScreen(
          publication: publication,
          chapter: chapter,
          subchapter: subchapter,
          allSubchapters: chapter.subchapters,
          currentIndex: currentIndex >= 0 ? currentIndex : 0,
        ),
      ),
    );
  }
}
