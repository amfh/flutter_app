import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../main.dart';
import '../services/offline_download_service.dart';
import '../services/publication_service.dart';
import '../services/new_publication_service.dart';
import '../services/local_storage_service.dart';
import '../services/product_publication_service.dart';
import '../models/publication.dart';

class MyPageScreen extends StatefulWidget {
  final String? idToken;
  final String? userEmail;

  const MyPageScreen({
    super.key,
    this.idToken,
    this.userEmail,
  });

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  Map<String, dynamic>? _decodedToken;
  String? _displayName;
  String? _email;
  List<String>? _products;

  // Smart caching and async loading
  final OfflineDownloadService _downloadService = OfflineDownloadService();
  final PublicationService _publicationService = PublicationService();
  final NewPublicationService _newPublicationService =
      NewPublicationService.instance;
  final ProductPublicationService _productPublicationService =
      ProductPublicationService.instance;
  final Map<String, Map<String, dynamic>> _statusCache = {};
  List<Publication> _publications = [];
  bool _publicationsLoaded = false;

  // Product information cache
  List<ProductInfo> _productInfos = [];
  bool _productInfosLoaded = false;

  // Cache keys for offline storage
  static const String _publicationsCacheKey = 'cached_publications.json';
  static const String _statusCacheKey = 'cached_publication_status.json';
  static const String _lastUpdateKey = 'publications_last_update.json';

  @override
  void initState() {
    super.initState();
    _parseTokenData();
    _loadPublicationsAsync();
    _loadProductInformationAsync();
  }

  void _parseTokenData() {
    try {
      // Bruk token fra UserSession hvis tilgjengelig
      final token = UserSession.instance.idToken ?? widget.idToken;
      final email = UserSession.instance.userEmail ?? widget.userEmail;

      if (token != null && token.isNotEmpty) {
        _decodedToken = JwtDecoder.decode(token);

        // Hent standardfelter
        _displayName = _decodedToken?['name'] ?? _decodedToken?['given_name'];
        _email =
            email ?? _decodedToken?['emails']?[0] ?? _decodedToken?['email'];

        // Hent extension_Products
        if (_decodedToken?['extension_Products'] != null) {
          final productsValue = _decodedToken!['extension_Products'];
          if (productsValue is String) {
            // Parse the raw string properly to extract only actual products
            _products = _parseProductsFromString(productsValue);
          } else if (productsValue is List) {
            // Filter out date-only entries if they exist
            _products = productsValue
                .cast<String>()
                .where((item) => !_isDateOnlyEntry(item))
                .toList();
          }
        }

        setState(() {});
      }
    } catch (e) {
      print('Error parsing token: $e');
    }
  }

  // Parse products from raw string, filtering out date-only entries
  List<String> _parseProductsFromString(String rawString) {
    final products = <String>[];

    // Split by comma and process each part
    final parts = rawString.split(',').map((e) => e.trim()).toList();

    String? currentProduct;
    String? validFrom;
    String? validTo;

    for (final part in parts) {
      if (part.contains('"Id"') &&
          part.contains('"ValidFrom"') &&
          part.contains('"ValidTo"')) {
        // This looks like a complete product entry with all info
        products.add(part);
      } else if (part.contains('"Id"')) {
        // Start of a new product
        currentProduct = part;
      } else if (part.contains('"ValidFrom"')) {
        validFrom = part;
      } else if (part.contains('"ValidTo"')) {
        validTo = part;

        // We have all parts, combine them
        if (currentProduct != null) {
          final combinedProduct = '$currentProduct,$validFrom,$validTo';
          products.add(combinedProduct);
          currentProduct = null;
          validFrom = null;
          validTo = null;
        }
      } else if (!_isDateOnlyEntry(part)) {
        // Regular product entry (simple ID or name)
        products.add(part);
      }
    }

    // Add any remaining product without complete date info
    if (currentProduct != null) {
      products.add(currentProduct);
    }

    return products;
  }

  // Check if an entry is just a date field (ValidFrom/ValidTo)
  bool _isDateOnlyEntry(String entry) {
    return entry.contains('"ValidFrom"') ||
        entry.contains('"ValidTo"') ||
        (entry.startsWith('"') && entry.contains('2025-') ||
            entry.contains('2026-'));
  }

  @override
  Widget build(BuildContext context) {
    // Sjekk om brukeren er logget inn
    final hasToken = UserSession.instance.idToken != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Min side'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: hasToken ? _buildLoggedInContent() : _buildNotLoggedInContent(),
    );
  }

  // Innhold for pålogget bruker
  Widget _buildLoggedInContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brukerinformasjon
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 32,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Brukerinformasjon',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_displayName != null) ...[
                    _buildInfoRow('Navn', _displayName!),
                    const SizedBox(height: 8),
                  ],
                  if (_email != null) ...[
                    _buildInfoRow('E-post', _email!),
                    const SizedBox(height: 8),
                  ],
                  if (_displayName == null && _email == null)
                    const Text(
                      'Ingen brukerinformasjon tilgjengelig',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  // Add last update check info
                  FutureBuilder<DateTime?>(
                    future: Future.value(null),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return Column(
                          children: [
                            const SizedBox(height: 8),
                            _buildInfoRow('Sist sjekket',
                                _formatUpdateDate(snapshot.data!)),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Oppdater tilganger knapp
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _refreshUserAccess();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Oppdater tilganger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Sjekk for oppdateringer knapp
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _checkForUpdates();
              },
              icon: const Icon(Icons.system_update),
              label: const Text('Sjekk for oppdateringer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Logg ut knapp
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showLogoutDialog(context);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logg ut'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tilgjengelige publikasjoner
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.library_books,
                        size: 32,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tilgjengelige publikasjoner',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  // Smart async publications with non-blocking UI
                  if (!_publicationsLoaded) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Laster publikasjoner...'),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    _buildPublicationsList(),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Produkter med publikasjoner
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_bag,
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Mine produkter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (!_productInfosLoaded) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ] else if (_productInfos.isNotEmpty) ...[
                    Text(
                      'Du har tilgang til ${_productInfos.length} produkt${_productInfos.length == 1 ? '' : 'er'} med til sammen ${_getTotalPublications()} publikasjoner:',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._productInfos.map(
                        (productInfo) => _buildProductInfoTile(productInfo)),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ingen produkter funnet. Kontakt administrator for å få tilgang til publikasjoner.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Debug info (kan fjernes i produksjon)
          if (_decodedToken != null) ...[
            const Text(
              'Debug informasjon:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'JWT Token Claims:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._decodedToken!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          '${entry.key}: ${entry.value}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Innhold for ikke-pålogget bruker
  Widget _buildNotLoggedInContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Du er ikke pålogget',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'For å se din brukerinformasjon og tilgjengelige publikasjoner må du logge inn først.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Gå tilbake til forrige side
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Gå tilbake'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const B2CLoginPageWrapper(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Logg inn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logg ut'),
          content: const Text('Er du sikker på at du vil logge ut?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Lukk dialog
              },
              child: const Text('Avbryt'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Close logout dialog first
                Navigator.of(context).pop();

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Logger ut...'),
                      ],
                    ),
                  ),
                );

                // Clear UserSession only (keep offline data)
                await UserSession.instance.clearSession();

                // Close loading dialog and navigate
                Navigator.of(context).pop();

                // Restart app eller gå til login-skjerm
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MyApp()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logg ut'),
            ),
          ],
        );
      },
    );
  }

  // Load publications with offline-first approach
  Future<void> _loadPublicationsAsync() async {
    try {
      final hasToken = UserSession.instance.idToken != null;
      if (!hasToken) {
        setState(() {
          _publicationsLoaded = true;
        });
        return;
      }

      // 1. First load from cache for immediate display
      await _loadFromCache();

      // 2. Check if we need to refresh (older than 1 hour or no cached data)
      final shouldRefresh = await _shouldRefreshData();
      final hasNoData = _publications.isEmpty;

      if (shouldRefresh || hasNoData) {
        // 3. If no cached data, fetch immediately; otherwise update in background
        if (hasNoData) {
          print('No cached data - fetching publications immediately');
          await _refreshDataInBackground();
        } else {
          // Update from API in background
          _refreshDataInBackground();
        }
      }
    } catch (e) {
      print('Error loading publications: $e');
      setState(() {
        _publicationsLoaded = true;
      });
    }
  }

  // Load publications and status from cache for immediate display
  Future<void> _loadFromCache() async {
    try {
      // Load publications from cache
      final cachedPublications =
          await LocalStorageService.readJson(_publicationsCacheKey);
      if (cachedPublications != null && cachedPublications is List) {
        final publications = cachedPublications
            .map((json) => Publication.fromJson(json))
            .toList();
        setState(() {
          _publications = publications;
          _publicationsLoaded = true;
        });
        print('Loaded ${publications.length} publications from cache');
      } else {
        // No cached data - set loaded to true and publications will be fetched from API
        print('No cached publications found');
        setState(() {
          _publications = [];
          _publicationsLoaded = true;
        });
      }

      // Load status from cache
      await _loadCachedPublicationStatus();
    } catch (e) {
      print('Error loading from cache: $e');
      setState(() {
        _publications = [];
        _publicationsLoaded = true;
      });
    }
  }

  // Load cached publication status immediately
  Future<void> _loadCachedPublicationStatus() async {
    try {
      final cachedStatus =
          await LocalStorageService.readJson(_statusCacheKey) ?? {};
      setState(() {
        for (final entry in cachedStatus.entries) {
          if (entry.value is Map<String, dynamic>) {
            final status = Map<String, dynamic>.from(entry.value);
            if (status['contentDate'] != null) {
              status['contentDate'] = DateTime.parse(status['contentDate']);
            }
            if (status['imagesDate'] != null) {
              status['imagesDate'] = DateTime.parse(status['imagesDate']);
            }
            // Ensure size values are integers
            status['contentSize'] = (status['contentSize'] as int?) ?? 0;
            status['imagesSize'] = (status['imagesSize'] as int?) ?? 0;
            status['imageCount'] = (status['imageCount'] as int?) ?? 0;
            _statusCache[entry.key] = status;
          }
        }
      });
    } catch (e) {
      print('Error loading cached status: $e');
    }
  }

  // Check if data should be refreshed (older than 1 hour)
  Future<bool> _shouldRefreshData() async {
    try {
      final lastUpdate = await LocalStorageService.readJson(_lastUpdateKey);
      if (lastUpdate == null || lastUpdate['timestamp'] == null) {
        return true; // No previous update
      }

      final lastUpdateTime = DateTime.parse(lastUpdate['timestamp']);
      final now = DateTime.now();
      final hoursSinceUpdate = now.difference(lastUpdateTime).inHours;

      return hoursSinceUpdate >= 1; // Refresh if older than 1 hour
    } catch (e) {
      print('Error checking refresh time: $e');
      return true; // Refresh on error
    }
  }

  // Refresh data from API in background
  Future<void> _refreshDataInBackground() async {
    try {
      print('Refreshing publications from API...');

      // Get fresh publications from service
      final publications = await _downloadService.getAccessiblePublications();

      // Save to cache
      final publicationsJson = publications.map((pub) => pub.toJson()).toList();
      await LocalStorageService.writeJson(
          _publicationsCacheKey, publicationsJson);

      // Update last refresh time
      await LocalStorageService.writeJson(_lastUpdateKey, {
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Update UI if publications changed
      if (publications.length != _publications.length ||
          !_publicationsEqual(publications, _publications)) {
        setState(() {
          _publications = publications;
        });
        print('Updated UI with ${publications.length} publications');
      }

      // Refresh status for all publications
      await _refreshAllPublicationStatus();
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  // Check if two publication lists are equal
  bool _publicationsEqual(List<Publication> list1, List<Publication> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) return false;
    }
    return true;
  }

  // Refresh status for all publications and save to cache
  Future<void> _refreshAllPublicationStatus() async {
    for (final pub in _publications) {
      try {
        final status = await _getPublicationStatus(pub.id);
        setState(() {
          _statusCache[pub.id] = status;
        });
      } catch (e) {
        print('Error refreshing status for ${pub.id}: $e');
      }
    }

    // Save updated status to cache
    await _saveStatusToCache();
  }

  // Get publication status including file sizes
  Future<Map<String, dynamic>> _getPublicationStatus(
      String publicationId) async {
    // Check content
    bool hasContent = false;
    int contentSize = 0;
    try {
      final data =
          await LocalStorageService.readJson('fullcontent_$publicationId.json');
      hasContent = data != null;
      if (hasContent) {
        contentSize = await _getContentSize(publicationId);
      }
    } catch (e) {
      hasContent = false;
    }

    // Check images
    final hasImages =
        await _publicationService.areImagesCachedForPublication(publicationId);
    int imagesSize = 0;
    int imageCount = 0;
    if (hasImages) {
      final imagesInfo = await _getImagesInfo(publicationId);
      imagesSize = imagesInfo['size'] ?? 0;
      imageCount = imagesInfo['count'] ?? 0;
    }

    // Get timestamps
    final contentDate = await _getTimestamp(publicationId, 'content');
    final imagesDate = await _getTimestamp(publicationId, 'images');

    return {
      'hasContent': hasContent,
      'hasImages': hasImages,
      'contentDate': contentDate,
      'imagesDate': imagesDate,
      'contentSize': contentSize,
      'imagesSize': imagesSize,
      'imageCount': imageCount,
    };
  }

  // Get content file size
  Future<int> _getContentSize(String publicationId) async {
    try {
      // Estimate size based on JSON content
      final data =
          await LocalStorageService.readJson('fullcontent_$publicationId.json');
      if (data != null) {
        // Rough estimation: convert to string and get byte length
        final jsonString = data.toString();
        return jsonString.length;
      }
    } catch (e) {
      print('Error getting content size: $e');
    }
    return 0;
  }

  // Get images info: count and total size by checking cached files
  Future<Map<String, int>> _getImagesInfo(String publicationId) async {
    try {
      int totalSize = 0;
      int imageCount = 0;

      // Try to count files directly by checking for existing cached image files
      // Start from index 0 and check until we find no more files
      for (int i = 0; i < 100; i++) {
        // Max 100 images per publication
        final imageFilename = 'content_img_${publicationId}_$i.img';
        final imageFile =
            await LocalStorageService.readImageFile(imageFilename);
        if (imageFile != null && await imageFile.exists()) {
          final fileSize = await imageFile.length();
          totalSize += fileSize;
          imageCount++;
        } else {
          // If we find a gap, stop counting (images should be sequential)
          break;
        }
      }

      return {
        'count': imageCount,
        'size': totalSize,
      };
    } catch (e) {
      print('Error getting images info: $e');
      return {'count': 0, 'size': 0};
    }
  }

  // Get timestamp for download
  Future<DateTime?> _getTimestamp(String publicationId, String type) async {
    try {
      final timestamps =
          await LocalStorageService.readJson('download_timestamps.json') ?? {};
      final timestamp = timestamps['${publicationId}_$type'];
      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  // Update timestamp
  Future<void> _updateTimestamp(String publicationId, String type) async {
    try {
      final timestamps =
          await LocalStorageService.readJson('download_timestamps.json') ?? {};
      timestamps['${publicationId}_$type'] = DateTime.now().toIso8601String();
      await LocalStorageService.writeJson(
          'download_timestamps.json', timestamps);
    } catch (e) {
      print('Error updating timestamp: $e');
    }
  }

  // Format bytes for display
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d siden';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}t siden';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m siden';
    } else {
      return 'Nå';
    }
  }

  // Build the publications list widget
  Widget _buildPublicationsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Du har tilgang til ${_publications.length} publikasjoner',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        if (_publications.isNotEmpty) ...[
          const Text(
            'Dine tilgjengelige publikasjoner:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ..._publications.map((pub) => _buildPublicationTile(pub)),
        ] else
          const Text(
            'Ingen publikasjoner tilgjengelig med dine nåværende tilganger',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
      ],
    );
  }

  // Build individual publication tile with download buttons and file sizes
  Widget _buildPublicationTile(Publication publication) {
    final status = _statusCache[publication.id] ??
        {
          'hasContent': false,
          'hasImages': false,
          'contentDate': null,
          'imagesDate': null,
          'contentSize': 0,
          'imagesSize': 0,
          'imageCount': 0,
        };

    final hasContent = status['hasContent'] as bool? ?? false;
    final hasImages = status['hasImages'] as bool? ?? false;
    final contentDate = status['contentDate'] as DateTime?;
    final imagesDate = status['imagesDate'] as DateTime?;
    final contentSize = (status['contentSize'] as int?) ?? 0;
    final imagesSize = (status['imagesSize'] as int?) ?? 0;
    final imageCount = (status['imageCount'] as int?) ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        publication.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasContent)
                        FutureBuilder<DateTime?>(
                          future:
                              _getLocalPublicationUpdateDate(publication.id),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Text(
                                'Nedlastet versjon: ${_formatUpdateDate(snapshot.data!)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                ),
                              );
                            } else if (publication.updateDate != null) {
                              return Text(
                                'Tilgjengelig versjon: ${_formatUpdateDate(publication.updateDate!)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
                          },
                        )
                      else if (publication.updateDate != null)
                        Text(
                          'Tilgjengelig versjon: ${_formatUpdateDate(publication.updateDate!)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Innhold:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      if (hasContent && contentDate != null) ...[
                        FutureBuilder<DateTime?>(
                          future:
                              _getLocalPublicationUpdateDate(publication.id),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Text(
                                'Versjon: ${_formatUpdateDate(snapshot.data!)}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.green),
                              );
                            } else if (publication.updateDate != null) {
                              return Text(
                                'Versjon: ${_formatUpdateDate(publication.updateDate!)}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.green),
                              );
                            } else {
                              return Text(
                                'Nedlastet: ${_formatUpdateDate(contentDate)}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.orange),
                              );
                            }
                          },
                        ),
                        Text(
                          'Størrelse: ${_formatBytes(contentSize)}',
                          style:
                              const TextStyle(fontSize: 9, color: Colors.blue),
                        ),
                      ] else
                        const Text(
                          'Ikke nedlastet',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      const SizedBox(height: 4),
                      ElevatedButton.icon(
                        onPressed: () => _downloadContent(publication),
                        icon: Icon(
                          hasContent ? Icons.refresh : Icons.download,
                          size: 16,
                        ),
                        label: Text(
                          hasContent ? 'Oppdater' : 'Last ned',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              hasContent ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bilder:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      if (hasImages && imagesDate != null) ...[
                        Text(
                          'Nedlastet: ${_formatDate(imagesDate)}',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.green),
                        ),
                        Text(
                          '$imageCount bilder (${_formatBytes(imagesSize)})',
                          style:
                              const TextStyle(fontSize: 9, color: Colors.blue),
                        ),
                      ] else
                        const Text(
                          'Ikke nedlastet',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      const SizedBox(height: 4),
                      ElevatedButton.icon(
                        onPressed: hasContent
                            ? () => _downloadImages(publication)
                            : null,
                        icon: Icon(
                          hasImages ? Icons.refresh : Icons.image,
                          size: 16,
                        ),
                        label: Text(
                          hasImages ? 'Oppdater' : 'Last ned',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              hasImages ? Colors.orange : Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Download content for publication using offline service
  Future<void> _downloadContent(Publication publication) async {
    final hasToken = UserSession.instance.idToken != null;
    if (!hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Du må være innlogget for å laste ned data')),
      );
      return;
    }

    // Show progress dialog
    double progress = 0.0;
    String statusText = 'Starter nedlastning...';

    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Laster ned innhold for:\n${publication.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    try {
      // Use NEW publication service to download content with progress tracking
      await _newPublicationService.downloadPublicationContentWithProgress(
        publication.id,
        onProgress: (double progressValue, String status) {
          dialogSetState?.call(() {
            progress = progressValue;
            statusText = status;
          });
        },
      );
      await _updateTimestamp(publication.id, 'content');

      // Update cached status
      final newStatus = await _getPublicationStatus(publication.id);
      setState(() {
        _statusCache[publication.id] = newStatus;
      });

      // Save updated status to cache
      await _saveStatusToCache();

      // Hide loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Offline innhold OG bilder nedlastet for: ${publication.title}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Hide loading dialog if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Feil ved offline nedlasting av ${publication.title}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Download images for publication using offline service
  Future<void> _downloadImages(Publication publication) async {
    final hasToken = UserSession.instance.idToken != null;
    if (!hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Du må være innlogget for å laste ned bilder')),
      );
      return;
    }

    // Show progress dialog
    double progress = 0.0;
    String statusText = 'Starter nedlastning av bilder...';
    int currentImage = 0;
    int totalImages = 0;

    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Laster ned bilder for:\n${publication.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (totalImages > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Bilde $currentImage av $totalImages',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );

    try {
      // Use NEW publication service to download images with progress tracking
      await _newPublicationService.downloadImagesForPublication(
        publication.id,
        onProgress: (double progressValue, String status) {
          dialogSetState?.call(() {
            progress = progressValue;
            statusText = status;
            // Parse image info from status message if possible
            final match = RegExp(r'(\d+) av (\d+)').firstMatch(status);
            if (match != null) {
              currentImage = int.tryParse(match.group(1) ?? '0') ?? 0;
              totalImages = int.tryParse(match.group(2) ?? '0') ?? 0;
            }
          });
        },
      );
      await _updateTimestamp(publication.id, 'images');

      // Update cached status
      final newStatus = await _getPublicationStatus(publication.id);
      setState(() {
        _statusCache[publication.id] = newStatus;
      });

      // Save updated status to cache
      await _saveStatusToCache();

      // Hide loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offline bilder nedlastet for: ${publication.title}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Hide loading dialog if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Feil ved offline bilderlasting for ${publication.title}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Save status cache to persistent storage
  Future<void> _saveStatusToCache() async {
    try {
      // Convert DateTime objects to strings for JSON serialization
      final statusToSave = <String, dynamic>{};
      for (final entry in _statusCache.entries) {
        final status = Map<String, dynamic>.from(entry.value);
        if (status['contentDate'] is DateTime) {
          status['contentDate'] =
              (status['contentDate'] as DateTime).toIso8601String();
        }
        if (status['imagesDate'] is DateTime) {
          status['imagesDate'] =
              (status['imagesDate'] as DateTime).toIso8601String();
        }
        statusToSave[entry.key] = status;
      }

      await LocalStorageService.writeJson(_statusCacheKey, statusToSave);
      print('Saved status cache for ${statusToSave.length} publications');
    } catch (e) {
      print('Error saving status cache: $e');
    }
  }

  // Refresh user access and check for new permissions
  Future<void> _refreshUserAccess() async {
    try {
      // Show loading indicator with dark background
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                SizedBox(height: 16),
                Text(
                  'Sjekker for nye tilganger...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      // Store old products for comparison
      final oldProducts = List<String>.from(_products ?? []);

      // Force refresh publications from API to see if we get access to more
      await _forceRefreshPublications();

      // Re-parse token data to get current claims
      _parseTokenData();

      // Compare old and new products
      final newProducts = _products ?? [];
      final hasNewAccess = _compareProductAccess(oldProducts, newProducts);

      // Hide loading dialog
      Navigator.of(context).pop();

      if (hasNewAccess) {
        // Show success message with details
        _showAccessUpdateDialog(oldProducts, newProducts);
      } else {
        // Show guidance message about needing fresh login for updated permissions
        _showRefreshGuidanceDialog();
      }
    } catch (e) {
      // Hide loading dialog if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feil ved sjekk av tilganger: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error refreshing user access: $e');
    }
  }

  // Compare old and new product access
  bool _compareProductAccess(
      List<String> oldProducts, List<String> newProducts) {
    if (oldProducts.length != newProducts.length) {
      return true; // Different number of products
    }

    // Check if any new products were added
    for (final product in newProducts) {
      if (!oldProducts.contains(product)) {
        return true; // New product found
      }
    }

    return false; // No changes
  }

  // Force refresh publications from API (ignoring cache)
  Future<void> _forceRefreshPublications() async {
    try {
      // Get fresh publications from API
      final publications = await _downloadService.getAccessiblePublications();

      // Update cache
      final publicationsJson = publications.map((pub) => pub.toJson()).toList();
      await LocalStorageService.writeJson(
          _publicationsCacheKey, publicationsJson);

      // Update last refresh time
      await LocalStorageService.writeJson(_lastUpdateKey, {
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Update UI
      setState(() {
        _publications = publications;
      });

      // Refresh status for all publications
      await _refreshAllPublicationStatus();

      print('Force refreshed publications: ${publications.length} found');
    } catch (e) {
      print('Error force refreshing publications: $e');
    }
  }

  // Show dialog with access update details
  void _showAccessUpdateDialog(
      List<String> oldProducts, List<String> newProducts) {
    final addedProducts =
        newProducts.where((p) => !oldProducts.contains(p)).toList();
    final removedProducts =
        oldProducts.where((p) => !newProducts.contains(p)).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Tilganger oppdatert!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (addedProducts.isNotEmpty) ...[
              const Text(
                'Nye tilganger:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              ...addedProducts.map((product) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.add, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Expanded(child: Text(product)),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
            ],
            if (removedProducts.isNotEmpty) ...[
              const Text(
                'Fjernede tilganger:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              ...removedProducts.map((product) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.remove, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Expanded(child: Text(product)),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
            ],
            Text(
              'Publikasjonslisten er oppdatert med ${_publications.length} tilgjengelige publikasjoner.',
              style: const TextStyle(fontSize: 14),
            ),
          ],
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

  // Show guidance dialog for when no new access is detected
  void _showRefreshGuidanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Ingen nye tilganger'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Det ble ikke funnet nye tilganger med gjeldende innlogging.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Hvis du tror du skal ha nye tilganger:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
                '• Kontakt administrator for å bekrefte at tilgangen er aktivert'),
            SizedBox(height: 4),
            Text('• Logg ut og inn igjen for å få oppdaterte rettigheter'),
            SizedBox(height: 4),
            Text('• Sjekk at du bruker riktig bruker for tilgangen'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showLogoutDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logg ut og inn igjen'),
          ),
        ],
      ),
    );
  }

  // Check for publication updates manually
  Future<void> _checkForUpdates() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Sjekker for oppdateringer...'),
            ],
          ),
        ),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show no updates available
      _showNoUpdatesDialog();
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feil ved sjekk av oppdateringer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show dialog when updates are available
  // Show dialog when no updates are available
  void _showNoUpdatesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Alt er oppdatert!'),
          ],
        ),
        content: const Text(
          'Alle dine nedlastede publikasjoner er allerede i siste versjon.',
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

  // Format update date for display
  String _formatUpdateDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // Get local publication update date from downloaded content
  Future<DateTime?> _getLocalPublicationUpdateDate(String publicationId) async {
    try {
      final contentData =
          await LocalStorageService.readJson('fullcontent_$publicationId.json');
      if (contentData != null && contentData['UpdateDate'] != null) {
        return DateTime.parse(contentData['UpdateDate'].toString());
      }
    } catch (e) {
      print('❌ Error reading local UpdateDate for $publicationId: $e');
    }
    return null;
  }

  // Load product information asynchronously
  Future<void> _loadProductInformationAsync() async {
    try {
      if (_products == null || _products!.isEmpty) {
        setState(() {
          _productInfosLoaded = true;
        });
        return;
      }

      // Load product publication mapping
      await _productPublicationService.loadAndCacheMapping();

      // Get product information for each user's product
      final productInfos = <ProductInfo>[];
      for (final productString in _products!) {
        final productInfo =
            await _productPublicationService.getProductInfo(productString);
        if (productInfo != null) {
          productInfos.add(productInfo);
        }
      }

      setState(() {
        _productInfos = productInfos;
        _productInfosLoaded = true;
      });
    } catch (e) {
      print('Error loading product information: $e');
      setState(() {
        _productInfosLoaded = true;
      });
    }
  }

  // Get total number of publications across all products
  int _getTotalPublications() {
    final Set<String> uniquePublications = {};
    for (final productInfo in _productInfos) {
      for (final pub in productInfo.publications) {
        uniquePublications.add(pub.id);
      }
    }
    return uniquePublications.length;
  }

  // Build product info tile with publications
  Widget _buildProductInfoTile(ProductInfo productInfo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            productInfo.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (productInfo.description.isNotEmpty) ...[
                Text(
                  productInfo.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                '${productInfo.publications.length} publikasjon${productInfo.publications.length == 1 ? '' : 'er'} tilgjengelig',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'AKTIV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            if (productInfo.publications.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Tilgjengelige publikasjoner:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              ...productInfo.publications
                  .map((pub) => _buildPublicationInfoTile(pub)),
              const SizedBox(height: 8),
            ] else
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Ingen publikasjoner tilgjengelig for dette produktet.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build publication info tile
  Widget _buildPublicationInfoTile(PublicationInfo publicationInfo) {
    // Check if publication is downloaded
    final isDownloaded =
        _statusCache[publicationInfo.id]?['hasContent'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.book,
            color: isDownloaded ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  publicationInfo.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                if (publicationInfo.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    publicationInfo.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDownloaded
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isDownloaded ? 'NEDLASTET' : 'TILGJENGELIG',
              style: TextStyle(
                color: isDownloaded ? Colors.green[700] : Colors.grey[600],
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
