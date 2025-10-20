import 'package:flutter/material.dart';
import 'dart:convert';
import '../widgets/main_scaffold.dart';

class SubChapterListScreen extends StatefulWidget {
  final Map<String, dynamic> chapterData;
  final String publicationId;
  const SubChapterListScreen(
      {super.key, required this.chapterData, required this.publicationId});

  @override
  State<SubChapterListScreen> createState() => _SubChapterListScreenState();
}

class _SubChapterListScreenState extends State<SubChapterListScreen> {
  List<Map<String, dynamic>> _subChapters = [];

  @override
  void initState() {
    super.initState();
    _loadSubChapters();
  }

  void _loadSubChapters() {
    // Extract subchapters from chapter data - check multiple possible field names
    final subchaptersData = widget.chapterData['Subchapters'] ??
        widget.chapterData['SubChapters'] ??
        widget.chapterData['subchapters'];

    if (subchaptersData is List) {
      setState(() {
        _subChapters = subchaptersData
            .map<Map<String, dynamic>>((subchapter) {
              if (subchapter is Map<String, dynamic>) {
                return {
                  'title': subchapter['Title'] ??
                      subchapter['Name'] ??
                      'Uten tittel',
                  'text': subchapter['Text'] ?? subchapter['Content'] ?? '',
                  'originalData': subchapter,
                };
              }
              return <String, dynamic>{};
            })
            .where((item) => item.isNotEmpty)
            .toList();
      });
    }
  }

  void _showSubChapterDetails(
      BuildContext context, Map<String, dynamic> subChapter) {
    final title = subChapter['title'] as String;
    final text = subChapter['text'] as String;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'UNDERKAPITTEL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (text.isNotEmpty) ...[
                    const Text(
                      'Tekst:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Divider(),
                  const Text(
                    'Rå JSON Data:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ')
                          .convert(subChapter['originalData']),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Lukk'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapterTitle =
        widget.chapterData['Title'] ?? widget.chapterData['Name'] ?? 'Kapittel';

    return MainScaffold(
      title: chapterTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Underkapitler i "$chapterTitle"',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_subChapters.length} underkapitler funnet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _subChapters.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Ingen underkapitler funnet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _subChapters.length,
                    itemBuilder: (context, index) {
                      final subChapter = _subChapters[index];
                      final title = subChapter['title'] as String;
                      final text = subChapter['text'] as String;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.article,
                            color: Colors.green,
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: text.isNotEmpty
                              ? Text(
                                  text.length > 100
                                      ? '${text.substring(0, 100)}...'
                                      : text,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'UNDERKAPITTEL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 16),
                            ],
                          ),
                          onTap: () =>
                              _showSubChapterDetails(context, subChapter),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
