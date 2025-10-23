import 'package:flutter/material.dart';
import '../widgets/new_main_scaffold.dart';
import '../services/new_user_data_service.dart';
import '../services/new_publication_service.dart';
import '../models/new_publication.dart';
import 'new_chapter_list_screen.dart';
import 'new_my_page_screen.dart';

class NewPublicationListScreen extends StatefulWidget {
  const NewPublicationListScreen({super.key});

  @override
  State<NewPublicationListScreen> createState() =>
      _NewPublicationListScreenState();
}

class _NewPublicationListScreenState extends State<NewPublicationListScreen> {
  final UserDataService _userDataService = UserDataService.instance;
  final NewPublicationService _publicationService =
      NewPublicationService.instance;

  List<Publication> _accessiblePublications = [];
  Map<String, bool> _downloadedStatus = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPublications();
  }

  Future<void> _loadPublications() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load accessible publications from user data
      final accessiblePublications =
          await _userDataService.getAccessiblePublications();

      // Check which publications are downloaded
      final downloadedIds =
          await _publicationService.getDownloadedPublicationIds();
      final downloadedStatus = <String, bool>{};

      for (final publication in accessiblePublications) {
        downloadedStatus[publication.id] =
            downloadedIds.contains(publication.id);
      }

      setState(() {
        _accessiblePublications = accessiblePublications;
        _downloadedStatus = downloadedStatus;
        _isLoading = false;
      });

      print(
          '📚 Loaded ${_accessiblePublications.length} accessible publications');
    } catch (e) {
      print('❌ Error loading publications: $e');
      setState(() {
        _errorMessage = 'Kunne ikke laste publikasjoner: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NewMainScaffold(
      title: 'Publikasjoner',
      currentRoute: '/publications',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Laster publikasjoner...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Feil',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPublications,
                icon: const Icon(Icons.refresh),
                label: const Text('Prøv igjen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_accessiblePublications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_books,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Ingen publikasjoner funnet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Du har ikke tilgang til noen publikasjoner, eller ingen publikasjoner er lastet ned.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewMyPageScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Gå til Min side for å laste ned'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPublications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _accessiblePublications.length,
        itemBuilder: (context, index) {
          final publication = _accessiblePublications[index];
          final isDownloaded = _downloadedStatus[publication.id] ?? false;

          return _buildPublicationCard(publication, isDownloaded);
        },
      ),
    );
  }

  Widget _buildPublicationCard(Publication publication, bool isDownloaded) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isDownloaded ? Colors.green : Colors.grey[300],
          child: Icon(
            isDownloaded ? Icons.library_books : Icons.cloud_download,
            color: isDownloaded ? Colors.white : Colors.grey[600],
          ),
        ),
        title: Text(
          publication.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // if (publication.title != null && publication.title!.isNotEmpty) ...[
            //   const SizedBox(height: 4),
            //   Text(
            //     publication.title!,
            //     style: TextStyle(
            //       fontSize: 14,
            //       color: Colors.grey[600],
            //     ),
            //   ),
            // ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isDownloaded ? Icons.check_circle : Icons.warning,
                  size: 16,
                  color: isDownloaded ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  isDownloaded ? 'Lastet ned' : 'Ikke lastet ned',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDownloaded ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (publication.chapterCount != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.menu_book,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${publication.chapterCount} kapitler',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: isDownloaded
            ? const Icon(Icons.arrow_forward_ios)
            : const Icon(Icons.download, color: Colors.orange),
        onTap: isDownloaded
            ? () => _openPublication(publication)
            : () => _showDownloadDialog(publication),
      ),
    );
  }

  void _openPublication(Publication publication) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewChapterListScreen(publication: publication),
      ),
    );
  }

  void _showDownloadDialog(Publication publication) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Last ned publikasjon'),
          content: Text(
            'Publikasjonen "${publication.name}" er ikke lastet ned. Gå til Min side for å laste ned publikasjoner.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NewMyPageScreen(),
                  ),
                );
              },
              child: const Text('Gå til Min side'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _publicationService.dispose();
    super.dispose();
  }
}
