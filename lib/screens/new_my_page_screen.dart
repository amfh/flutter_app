import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/new_main_scaffold.dart';
import '../services/new_user_data_service.dart';
import '../services/new_publication_service.dart';
import '../models/user_data.dart';
import '../models/new_publication.dart';

class NewMyPageScreen extends StatefulWidget {
  const NewMyPageScreen({super.key});

  @override
  State<NewMyPageScreen> createState() => _NewMyPageScreenState();
}

class _NewMyPageScreenState extends State<NewMyPageScreen> {
  final UserDataService _userDataService = UserDataService.instance;
  final NewPublicationService _publicationService =
      NewPublicationService.instance;

  UserData? _userData;
  Map<String, bool> _downloadStatus = {};
  bool _isLoading = true;
  bool _isOnline = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    _loadData();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final isConnected = results.isNotEmpty &&
          !results.every((result) => result == ConnectivityResult.none);
      if (mounted && isConnected != _isOnline) {
        setState(() {
          _isOnline = isConnected;
        });
        print('📶 Connectivity changed: ${isConnected ? 'Online' : 'Offline'}');
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load user data
      final userData = await _userDataService.loadUserData();

      if (userData == null) {
        setState(() {
          _errorMessage = 'Ingen brukerdata funnet. Logg inn på nytt.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _userData = userData;
      });

      // Check internet connection
      await _checkConnectivity();

      // Load download status for publications
      await _loadDownloadStatus();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        _errorMessage = 'Feil ved lasting av data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final isConnected = connectivityResults.isNotEmpty &&
          !connectivityResults
              .every((result) => result == ConnectivityResult.none);

      if (mounted) {
        setState(() {
          _isOnline = isConnected;
        });
      }

      print(
          '📶 Initial connectivity check: ${isConnected ? 'Online' : 'Offline'}');

      // Don't automatically fetch publications - only when user clicks refresh
    } catch (e) {
      print('❌ Error checking connectivity: $e');
      if (mounted) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }

  Future<void> _fetchLatestPublications() async {
    try {
      final apiPublications = await _publicationService.fetchPublications();

      // Update user data with new version dates from API
      if (_userData != null) {
        final updatedPublications = <Publication>[];

        for (final userPub in _userData!.availablePublications) {
          // Find corresponding API publication
          final apiPub = apiPublications.firstWhere(
            (p) => p.id == userPub.id,
            orElse: () => userPub,
          );

          // Create updated publication with new version date from API
          final updatedPub = Publication(
            id: userPub.id,
            name: userPub.name,
            title: userPub.title,
            imageUrl: userPub.imageUrl,
            url: userPub.url,
            createDate: userPub.createDate,
            updateDate: userPub.updateDate, // Keep original version date
            newVersionDate: apiPub.updateDate, // Set new version date from API
            restrictPublicAccessIds: userPub.restrictPublicAccessIds,
            dataSizeInBytes: userPub.dataSizeInBytes,
            dataSize: userPub.dataSize,
            chapterCount: userPub.chapterCount,
            subchapterCount: userPub.subchapterCount,
          );

          updatedPublications.add(updatedPub);
        }

        // Update user data with publications containing new version dates
        final updatedUserData = UserData(
          email: _userData!.email,
          lastUpdated: DateTime.now(),
          availablePublications: updatedPublications,
          subscriptions: _userData!.subscriptions,
        );

        await _userDataService.saveUserData(updatedUserData);

        setState(() {
          _userData = updatedUserData;
        });
      }
    } catch (e) {
      print('❌ Error fetching publications: $e');
      // Don't show error to user if we can't fetch - offline mode should still work
    }
  }

  Future<void> _loadDownloadStatus() async {
    try {
      if (_userData == null) return;

      print('🔄 Loading download status...');
      final downloadedIds =
          await _publicationService.getDownloadedPublicationIds();
      final status = <String, bool>{};

      for (final publication in _userData!.availablePublications) {
        status[publication.id] = downloadedIds.contains(publication.id);
      }

      if (mounted) {
        setState(() {
          _downloadStatus = status;
        });
      }
      print('✅ Download status loaded successfully');
    } catch (e) {
      print('❌ Error loading download status: $e');
      // Don't rethrow - let the app continue with current status
    }
  }

  // Update publication's updateDate after successful download
  Future<void> _updatePublicationAfterDownload(String publicationId) async {
    try {
      if (_userData == null) return;

      print(
          '📝 Updating publication updateDate after download: $publicationId');

      // Fetch latest publication data from API to get current updateDate
      final apiPublications = await _publicationService.fetchPublications();
      final apiPub = apiPublications.firstWhere(
        (p) => p.id == publicationId,
        orElse: () => throw Exception('Publication not found in API'),
      );

      // Update the specific publication in user data
      final updatedPublications = _userData!.availablePublications.map((pub) {
        if (pub.id == publicationId) {
          return Publication(
            id: pub.id,
            name: pub.name,
            title: pub.title,
            imageUrl: pub.imageUrl,
            url: pub.url,
            createDate: pub.createDate,
            updateDate: apiPub.updateDate, // Update with latest from API
            newVersionDate: pub.newVersionDate, // Keep existing newVersionDate
            restrictPublicAccessIds: pub.restrictPublicAccessIds,
            dataSizeInBytes: pub.dataSizeInBytes,
            dataSize: pub.dataSize,
            chapterCount: pub.chapterCount,
            subchapterCount: pub.subchapterCount,
          );
        }
        return pub;
      }).toList();

      // Save updated user data
      final updatedUserData = UserData(
        email: _userData!.email,
        lastUpdated: DateTime.now(),
        availablePublications: updatedPublications,
        subscriptions: _userData!.subscriptions,
      );

      await _userDataService.saveUserData(updatedUserData);

      if (mounted) {
        setState(() {
          _userData = updatedUserData;
        });
      }

      print('✅ Publication updateDate updated successfully');
    } catch (e) {
      print('❌ Error updating publication after download: $e');
      // Don't show error to user - the download was still successful
    }
  }

  @override
  Widget build(BuildContext context) {
    return NewMainScaffold(
      title: 'Min side',
      currentRoute: '/my-page',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    print(
        '🖼️ Building body - isLoading: $_isLoading, errorMessage: $_errorMessage, userData: ${_userData != null}');

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Laster brukerdata...'),
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
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Prøv igjen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_userData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Ingen brukerdata tilgjengelig'),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    try {
      return RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserInfoCard(),
              const SizedBox(height: 16),
              _buildSubscriptionsCard(),
              const SizedBox(height: 16),
              _buildPublicationsCard(),
              const SizedBox(height: 16),
              _buildConnectionStatusCard(),
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Error building body: $e');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Feil ved visning av innhold'),
              const SizedBox(height: 8),
              Text('$e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Last på nytt'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildUserInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Brukerinformasjon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Text(
                  'E-post: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(_userData?.email ?? 'Ukjent'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Sist oppdatert: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(_formatDate(_userData?.lastUpdated)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  color: _isOnline ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _isOnline ? Colors.green : Colors.orange,
                  ),
                ),
                const Spacer(),
                if (_isOnline && !_isRefreshing)
                  TextButton.icon(
                    onPressed: _refreshData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Oppdater'),
                  )
                else if (_isRefreshing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'For å sjekke om det er nye versjoner av publikasjoner, trykk på Oppdater. Deretter se om det kommer opp Oppdater knapp ved publikasjon på denne sida',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.card_membership,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Mine abonnementer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (_userData?.subscriptions.isEmpty ?? true) ...[
              const Text('Ingen abonnementer funnet'),
            ] else ...[
              ..._userData!.subscriptions.map((sub) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: sub.isActive
                              ? Colors.green[300]!
                              : Colors.red[300]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: sub.isActive ? Colors.green[50] : Colors.red[50],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                sub.isActive
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                size: 20,
                                color: sub.isActive ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  sub.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      sub.isActive ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  sub.isActive ? 'Aktiv' : 'Utløpt',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Utløper: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                sub.expiryDate != null
                                    ? _formatDate(sub.expiryDate!)
                                    : 'Ingen utløpsdato',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: sub.isActive
                                      ? Colors.grey[700]
                                      : Colors.red,
                                  fontWeight: sub.isActive
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (sub.expiryDate != null && sub.isActive) ...[
                            const SizedBox(height: 4),
                            Text(
                              _getDaysUntilExpiry(sub.expiryDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getDaysLeft(sub.expiryDate!) <= 30
                                    ? Colors.orange[700]
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mangler du abonnement eller har fått nytt abonnement? Logg ut og inn igjen på appen.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.library_books,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tilgjengelige publikasjoner',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (_userData?.availablePublications.isEmpty ?? true) ...[
              const Text('Ingen publikasjoner tilgjengelig'),
            ] else ...[
              ..._userData!.availablePublications
                  .map((pub) => _buildPublicationItem(pub)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPublicationItem(Publication publication) {
    final isDownloaded = _downloadStatus[publication.id] ?? false;
    final hasUpdate = _hasUpdate(publication);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  publication.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (hasUpdate)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Oppdatering',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isDownloaded ? Icons.check_circle : Icons.download,
                size: 16,
                color: isDownloaded ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                isDownloaded ? 'Lastet ned' : 'Ikke lastet ned',
                style: TextStyle(
                  fontSize: 12,
                  color: isDownloaded ? Colors.green : Colors.grey,
                ),
              ),
              const Spacer(),
              Text(
                'Versjonsdato: ${_formatDate(publication.updateDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (_isOnline && (!isDownloaded || hasUpdate)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadPublication(publication),
                icon: Icon(hasUpdate ? Icons.update : Icons.download),
                label: Text(hasUpdate ? 'Oppdater' : 'Last ned'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasUpdate ? Colors.orange : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasUpdate(Publication publication) {
    // Check if there's a newer version available
    if (publication.newVersionDate == null) return false;

    return publication.newVersionDate!.isAfter(publication.updateDate);
  }

  Future<void> _downloadPublication(Publication publication) async {
    bool cancelled = false;
    double progress = 0.0;
    String statusText = 'Forbereder nedlasting...';
    late StateSetter dialogSetState;

    // Track if dialog was closed early
    bool dialogClosed = false;

    // Simple approach: Use a popup and track context properly
    void closeDialog() {
      dialogClosed = true;
      if (mounted) {
        try {
          // Check if we can actually pop before trying
          final navigator = Navigator.of(context, rootNavigator: true);
          if (navigator.canPop()) {
            navigator.pop();
          }
        } catch (e) {
          print('⚠️ Error closing dialog: $e');
          // Try alternative approach
          try {
            Navigator.of(context).pop();
          } catch (e2) {
            print('⚠️ Alternative dialog close also failed: $e2');
          }
        }
      }
    }

    // Show the dialog with progress
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState; // Store the setState function
          return AlertDialog(
            title: const Text('Laster ned publikasjon'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: progress),
                const SizedBox(height: 16),
                Text('${(progress * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(statusText),
                const SizedBox(height: 8),
                Text(
                  publication.name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                if (publication.dataSizeInBytes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Størrelse: ${_formatDataSize(publication.dataSizeInBytes!)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  print('🚫 Bruker trykket avbryt - stopper nedlasting');
                  cancelled = true;
                  dialogClosed = true;
                  try {
                    if (Navigator.of(dialogContext).canPop()) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (e) {
                    print('⚠️ Error closing dialog from cancel button: $e');
                    // Try alternative approach
                    try {
                      Navigator.of(context).pop();
                    } catch (e2) {
                      print('⚠️ Alternative cancel close failed: $e2');
                    }
                  }
                },
                child: const Text('Avbryt'),
              ),
            ],
          );
        },
      ),
    );

    // Note: Removed automatic timer close - let download complete naturally

    try {
      // Short delay to let dialog render before starting
      await Future.delayed(const Duration(milliseconds: 100));

      // Check if already cancelled
      if (cancelled || dialogClosed) {
        print('🚫 Nedlasting avbrutt før start');
        return;
      }

      // Download with progress tracking
      await _publicationService.downloadPublicationContentWithProgress(
        publication.id,
        expectedSizeInBytes: publication.dataSizeInBytes,
        isCancelled: () => cancelled || dialogClosed,
        onProgress: (double newProgress, String status) {
          if (!cancelled && !dialogClosed && mounted) {
            try {
              dialogSetState(() {
                progress = newProgress;
                statusText = status;
              });
              print('📊 Progress: ${(newProgress * 100).toInt()}% - $status');
            } catch (e) {
              print('⚠️ Error updating progress: $e');
            }
          } else if (cancelled || dialogClosed) {
            print('🚫 Progress oppdatering stoppet - nedlasting avbrutt');
          }
        },
      );

      if (cancelled || dialogClosed || !mounted) {
        print('🚫 Nedlasting fullført men avbrutt - ignorerer resultat');
        return;
      }

      // Close dialog immediately
      closeDialog();

      // Wait a moment for dialog to close
      await Future.delayed(const Duration(milliseconds: 100));

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${publication.name} er lastet ned med bilder'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Background updates without awaiting
        _updatePublicationAfterDownload(publication.id).catchError((e) {
          print('❌ Background publication update failed: $e');
        });

        _loadDownloadStatus()
            .catchError((e) => print('❌ Error updating download status: $e'));
      }
    } catch (e) {
      if (cancelled || dialogClosed) {
        print('🚫 Nedlasting avbrutt av bruker');
        return;
      }

      if (!mounted) return;

      closeDialog();
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        String errorMessage = 'Nedlasting feilet. Prøv igjen senere.';
        if (e.toString().contains('timeout')) {
          errorMessage =
              'Nedlasting tok for lang tid. Sjekk internettforbindelsen.';
        } else if (e.toString().contains('Connection') ||
            e.toString().contains('Socket')) {
          errorMessage =
              'Kan ikke koble til server. Sjekk internettforbindelsen.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('❌ Feil ved nedlasting'),
                const SizedBox(height: 4),
                Text(errorMessage, style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Prøv igjen',
              textColor: Colors.white,
              onPressed: () => _downloadPublication(publication),
            ),
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _checkConnectivity();

      // Only fetch publications when user manually refreshes
      if (_isOnline) {
        await _fetchLatestPublications();
      }

      await _loadDownloadStatus();
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Ukjent';

    return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  int _getDaysLeft(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    return difference.inDays;
  }

  String _getDaysUntilExpiry(DateTime expiryDate) {
    final daysLeft = _getDaysLeft(expiryDate);

    if (daysLeft < 0) {
      return 'Utløpt for ${(-daysLeft)} dager siden';
    } else if (daysLeft == 0) {
      return 'Utløper i dag';
    } else if (daysLeft == 1) {
      return 'Utløper i morgen';
    } else if (daysLeft <= 7) {
      return 'Utløper om $daysLeft dager';
    } else if (daysLeft <= 30) {
      return 'Utløper om $daysLeft dager';
    } else {
      final weeks = (daysLeft / 7).round();
      final months = (daysLeft / 30).round();

      if (daysLeft <= 60) {
        return 'Utløper om $weeks uker';
      } else {
        return 'Utløper om $months måneder';
      }
    }
  }

  String _formatDataSize(int sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _publicationService.dispose();
    super.dispose();
  }
}
