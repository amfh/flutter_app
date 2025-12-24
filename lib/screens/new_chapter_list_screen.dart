import 'package:flutter/material.dart';
import '../services/new_publication_service.dart';
import '../services/new_user_data_service.dart';
import '../models/new_publication.dart';
import 'new_subchapter_list_screen.dart';

class NewChapterListScreen extends StatefulWidget {
  final Publication publication;

  const NewChapterListScreen({
    super.key,
    required this.publication,
  });

  @override
  State<NewChapterListScreen> createState() => _NewChapterListScreenState();
}

class _NewChapterListScreenState extends State<NewChapterListScreen> {
  final NewPublicationService _publicationService =
      NewPublicationService.instance;

  List<Chapter> _chapters = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _subscriptionExpired = false;
  List<String> _expiredSubscriptionNames = [];

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Check subscription status for this publication
      final subscriptionStatus = await UserDataService.instance
          .checkPublicationSubscriptionStatus(widget.publication.id);

      if (subscriptionStatus.isExpired) {
        setState(() {
          _subscriptionExpired = true;
          _expiredSubscriptionNames =
              subscriptionStatus.expiredSubscriptionNames;
        });
        print(
            '⚠️ Subscription expired for ${widget.publication.name}: $_expiredSubscriptionNames');
      }

      final chapters = await _publicationService
          .loadPublicationContent(widget.publication.id);

      if (chapters == null) {
        setState(() {
          _errorMessage =
              'Publikasjonen er ikke lastet ned. Gå til Min side for å laste den ned.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });

      print(
          '📖 Loaded ${_chapters.length} chapters for ${widget.publication.name}');

      // Debug: Print chapter details
      print('🔍 === CHAPTER DETAILS IN LIST SCREEN ===');
      for (int i = 0; i < _chapters.length; i++) {
        final chapter = _chapters[i];
        print('Chapter ${i + 1}:');
        print('  Title: "${chapter.title}"');
        print('  Subtitle: "${chapter.subtitle}"');
        print('  Number: "${chapter.number}"');
        print('  Subchapters: ${chapter.subchapters.length}');
      }
    } catch (e) {
      print('❌ Error loading chapters: $e');
      setState(() {
        _errorMessage = 'Kunne ikke laste kapitler: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.publication.name),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
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
            Text('Laster kapitler...'),
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
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Gå tilbake'),
              ),
            ],
          ),
        ),
      );
    }

    if (_chapters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_book,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Ingen kapitler funnet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Denne publikasjonen inneholder ingen kapitler.',
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

    // Block access if subscription is expired
    if (_subscriptionExpired) {
      return _buildSubscriptionExpiredBlock();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _chapters.length,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        return _buildChapterCard(chapter, index);
      },
    );
  }

  Widget _buildSubscriptionExpiredBlock() {
    final subscriptionNames = _expiredSubscriptionNames.isNotEmpty
        ? _expiredSubscriptionNames.join(', ')
        : 'Ukjent abonnement';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange[300]!, width: 2),
              ),
              child: Icon(
                Icons.lock_clock,
                size: 80,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Abonnement utgått',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange[900],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Abonnementet "$subscriptionNames" som gir tilgang til denne publikasjonen er utgått.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Forny abonnementet for å få tilgang til innholdet.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Gå tilbake'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep the old banner method for reference (not used now)
  Widget _buildSubscriptionExpiredBanner() {
    final subscriptionNames = _expiredSubscriptionNames.isNotEmpty
        ? _expiredSubscriptionNames.join(', ')
        : 'Ukjent abonnement';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange[700],
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abonnement utgått',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Abonnementet "$subscriptionNames" som gir tilgang til denne publikasjonen er utgått. Forny abonnementet for å få tilgang til oppdatert innhold.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(Chapter chapter, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          chapter.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chapter.subtitle != null && chapter.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                chapter.subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (chapter.number != null && chapter.number!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Kapittel ${chapter.number}',
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
                  Icons.article,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${chapter.subchapters.length} underkapitler',
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
        onTap: () => _openChapter(chapter),
      ),
    );
  }

  void _openChapter(Chapter chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewSubchapterListScreen(
          publication: widget.publication,
          chapter: chapter,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _publicationService.dispose();
    super.dispose();
  }
}
