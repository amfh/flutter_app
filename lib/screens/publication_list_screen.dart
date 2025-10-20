import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/publication.dart';
import '../services/publication_service.dart';
import 'publication_detail_screen.dart';
import '../widgets/main_scaffold.dart';

class PublicationListScreen extends StatefulWidget {
  const PublicationListScreen({super.key});

  @override
  State<PublicationListScreen> createState() => _PublicationListScreenState();
}

class _PublicationListScreenState extends State<PublicationListScreen>
    with WidgetsBindingObserver {
  final PublicationService _service = PublicationService();
  late Future<List<Publication>> _publications;
  String _lastDataSource = '';
  bool _hasBeenPaused = false;

  // HTTP client that accepts self-signed certificates
  late HttpClient _httpClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Configure HTTP client to accept self-signed certificates
    _httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Accept all certificates for localhost development
        return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
      };

    _publications = _loadPublicationsWithCache();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      _hasBeenPaused = true;
      print('App paused - marking for refresh on resume');
    } else if (state == AppLifecycleState.resumed && _hasBeenPaused) {
      _hasBeenPaused = false;
      print('App resumed after pause - refreshing publications');
      _refreshPublications();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this screen from another screen
    print('Dependencies changed - refreshing publications');
    Future.microtask(() {
      if (mounted) {
        _refreshPublications();
      }
    });
  }

  void _refreshPublications() {
    print('Refreshing publications list...');
    setState(() {
      _publications = _loadPublicationsWithCache();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _httpClient.close();
    super.dispose();
  }

  Future<List<Publication>> _loadPublicationsWithCache() async {
    try {
      // Load publications from the same cache used by my_page_screen
      final cachedPublications = await _service.getCachedPublications();
      if (cachedPublications.isNotEmpty) {
        print('Loading publications from cached storage');
        _lastDataSource =
            'Offline nedlastede publikasjoner (${cachedPublications.length} publikasjoner)';
        return cachedPublications;
      }

      // No cached data available - show empty list with message
      print('No cached publications available');
      _lastDataSource =
          'Ingen offline publikasjoner tilgjengelig - gå til Min side for å laste ned';
      return [];
    } catch (e) {
      print('Error loading cached publications: $e');
      _lastDataSource = 'Feil ved lasting av offline publikasjoner';
      return [];
    }
  }

  Future<String> _getDataSourceInfo() async {
    return _lastDataSource;
  }

  Future<void> _testApiConnection() async {
    final urls = [
      'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublications',
      'https://nye.kompetansebiblioteket.no/umbraco/api/AppApi/GetPublications',
      // 'http://10.0.2.2:44342/umbraco/api/AppApi/GetPublications',
      // 'https://10.0.2.2:44342/umbraco/api/AppApi/GetPublications',
      // 'http://localhost:44342/umbraco/api/AppApi/GetPublications',
      // 'https://localhost:44342/umbraco/api/AppApi/GetPublications',
      // 'http://127.0.0.1:44342/umbraco/api/AppApi/GetPublications',
      // 'https://127.0.0.1:44342/umbraco/api/AppApi/GetPublications',
    ];

    String results = 'API Test Results:\n\n';

    for (String url in urls) {
      try {
        http.Response response;

        if (url.startsWith('https://')) {
          // Use custom HTTP client for HTTPS URLs
          final request = await _httpClient.getUrl(Uri.parse(url));
          request.headers.set('Content-Type', 'application/json');
          final httpResponse =
              await request.close().timeout(const Duration(seconds: 5));
          final responseBody =
              await httpResponse.transform(utf8.decoder).join();
          response = http.Response(responseBody, httpResponse.statusCode);
        } else {
          // Use regular http package for HTTP URLs
          response = await http.get(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 5));
        }

        results += '✅ $url\n';
        results += 'Status: ${response.statusCode}\n';
        results += 'Body length: ${response.body.length} chars\n\n';

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List) {
            results += 'Publications found: ${data.length}\n\n';
          }
        }
      } catch (e) {
        results += '❌ $url\n';
        results += 'Error: $e\n\n';
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API Test'),
          content: SingleChildScrollView(
            child: Text(results, style: const TextStyle(fontSize: 12)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Publikasjoner',
      actions: [
        IconButton(
          icon: const Icon(Icons.bug_report),
          tooltip: 'Test API',
          onPressed: _testApiConnection,
        ),
      ],
      body: Column(
        children: [
          // Data source status banner
          FutureBuilder<String>(
            future: _getDataSourceInfo(),
            builder: (context, snapshot) {
              final sourceInfo = snapshot.data ?? '';
              if (sourceInfo.isEmpty) return const SizedBox.shrink();

              final isOffline = sourceInfo.contains('Offline nedlastede');
              final isEmpty = sourceInfo.contains('Ingen offline');

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: isOffline
                      ? Colors.green.withOpacity(0.1)
                      : isEmpty
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: isOffline
                        ? Colors.green.withOpacity(0.3)
                        : isEmpty
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOffline
                          ? Icons.offline_bolt
                          : isEmpty
                              ? Icons.download_for_offline
                              : Icons.error_outline,
                      color: isOffline
                          ? Colors.green
                          : isEmpty
                              ? Colors.orange
                              : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sourceInfo,
                        style: TextStyle(
                          color: isOffline
                              ? Colors.green[700]
                              : isEmpty
                                  ? Colors.orange[700]
                                  : Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Publications list
          Expanded(
            child: FutureBuilder<List<Publication>>(
              future: _publications,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Feil: ${snapshot.error}"));
                }
                final pubs = snapshot.data ?? [];
                if (pubs.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      _refreshPublications();
                      // Wait for the future to complete
                      await _publications;
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.download_for_offline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Ingen offline publikasjoner',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Gå til Min side for å laste ned publikasjoner for offline bruk.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Dra ned for å oppdatere',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _refreshPublications();
                    // Wait for the future to complete
                    await _publications;
                  },
                  child: ListView.builder(
                    itemCount: pubs.length,
                    itemBuilder: (context, index) {
                      final pub = pubs[index];
                      return FutureBuilder<bool>(
                        future: _service.hasFullContentCache(pub.id),
                        builder: (context, snapshot) {
                          final hasCache = snapshot.data == true;
                          return FutureBuilder<File?>(
                            future: _service.getCachedImageFile(pub.id),
                            builder: (context, imgSnapshot) {
                              Widget imageWidget;
                              if (imgSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                imageWidget = const SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)));
                              } else if (imgSnapshot.hasData &&
                                  imgSnapshot.data != null) {
                                imageWidget = Image.file(
                                  imgSnapshot.data!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.book_sharp),
                                );
                              } else if (pub.imageUrl.isNotEmpty) {
                                // Download and cache image if not present
                                imageWidget = FutureBuilder<File?>(
                                  future: _service.downloadAndCacheImage(
                                      pub.imageUrl, pub.id),
                                  builder: (context, downloadSnapshot) {
                                    if (downloadSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2)));
                                    } else if (downloadSnapshot.hasData &&
                                        downloadSnapshot.data != null) {
                                      return Image.file(
                                        downloadSnapshot.data!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.book_sharp),
                                      );
                                    } else {
                                      return const Icon(Icons.book_sharp);
                                    }
                                  },
                                );
                              } else {
                                imageWidget = const Icon(Icons.book);
                              }
                              return ListTile(
                                leading: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    imageWidget,
                                    if (hasCache)
                                      const Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Icon(Icons.check_circle,
                                            color: Colors.green, size: 20),
                                      ),
                                  ],
                                ),
                                title: Text(pub.title),
                                subtitle: Text(
                                  pub.ingress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PublicationDetailScreen(
                                          publication: pub),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
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
