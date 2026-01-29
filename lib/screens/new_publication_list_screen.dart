import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/new_main_scaffold.dart';
import '../services/new_user_data_service.dart';
import '../services/new_publication_service.dart';
import '../models/new_publication.dart';
import '../models/user_data.dart';
import 'new_chapter_list_screen.dart';
// import 'new_my_page_screen.dart';

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

  List<Publication> _publications = [];
  Map<String, bool> _downloadStatus = {};
  bool _isLoading = true;
  bool _isOnline = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  UserData? _userData;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    _loadPublications();
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
        print('📶 Connectivity changed: ${isConnected ? "Online" : "Offline"}');
      }
    });
  }

  Future<void> _loadPublications() async {
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
        _publications = userData.availablePublications;
      });

      // Debug: Print publication IDs from loaded user data
      print('🔍 === PUBLICATIONS FROM USER DATA ===');
      for (final pub in userData.availablePublications) {
        print('📦 ID: "${pub.id}" | Name: "${pub.name}"');
      }

      // Check internet connection
      await _checkConnectivity();

      // Load download status for publications
      final downloadedIds =
          await _publicationService.getDownloadedPublicationIds();
      final status = <String, bool>{};
      for (final publication in userData.availablePublications) {
        status[publication.id] = downloadedIds.contains(publication.id);
      }
      setState(() {
        _downloadStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Kunne ikke laste publikasjoner: $e';
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
          '📶 Initial connectivity check: ${isConnected ? "Online" : "Offline"}');
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
            updateDate: userPub.updateDate,
            newVersionDate: apiPub.updateDate,
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
          _publications = updatedPublications;
        });
      }
    } catch (e) {
      print('❌ Error fetching publications: $e');
      // Don't show error to user if we can't fetch - offline mode should still work
    }
  }

  Future<void> _updatePublications() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _checkConnectivity();

      // Fetch latest publications from API
      if (_isOnline) {
        await _fetchLatestPublications();
      }

      // Reload download status
      final downloadedIds =
          await _publicationService.getDownloadedPublicationIds();
      final status = <String, bool>{};
      for (final publication in _publications) {
        status[publication.id] = downloadedIds.contains(publication.id);
      }
      setState(() {
        _downloadStatus = status;
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
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
            newVersionDate:
                apiPub.updateDate, // Also update newVersionDate to match
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
          _publications = updatedPublications;
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

    if (_publications.isEmpty) {
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
                'Ingen publikasjoner tilgjengelig',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _publications.length + 1, // +1 for connection status card
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildConnectionStatusCard(),
          );
        }
        final publication = _publications[index - 1];
        final isDownloaded = _downloadStatus[publication.id] ?? false;
        final hasUpdate = _hasUpdate(publication);
        return _buildPublicationItem(publication, isDownloaded, hasUpdate);
      },
    );
  }

  Widget _buildConnectionStatusCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isOnline ? const Color(0xFF0974ba) : Colors.grey[400]!,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        _isOnline ? const Color(0xFF0974ba) : Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color:
                        _isOnline ? const Color(0xFF0974ba) : Colors.grey[700],
                  ),
                ),
                const Spacer(),
                if (_isOnline)
                  ElevatedButton.icon(
                    onPressed: _isRefreshing ? null : _updatePublications,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(_isRefreshing ? 'Oppdaterer...' : 'Oppdater'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0974ba),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _isOnline
                  ? 'For å sjekke om det er nye versjoner av publikasjoner, trykk på Oppdater. Deretter se om det kommer opp Oppdater knapp ved publikasjon på denne siden.'
                  : 'Du er offline. Koble til internett for å laste ned nye publikasjoner eller oppdateringer.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0974ba).withOpacity(0.1),
                    const Color(0xFF0974ba).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF0974ba).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0974ba),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mangler du abonnement eller har fått nytt abonnement? Gå til min side for å sjekke det!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.4,
                        fontWeight: FontWeight.w500,
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

  Widget _buildPublicationItem(
      Publication publication, bool isDownloaded, bool hasUpdate) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    publication.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Color(0xFF1a1a1a),
                    ),
                  ),
                ),
                if (hasUpdate)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF6F00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Oppdatering',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isDownloaded ? const Color(0xFFE8F5E9) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDownloaded ? Icons.check_circle : Icons.download_outlined,
                    size: 18,
                    color: isDownloaded
                        ? const Color(0xFF2E7D32)
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDownloaded ? 'Lastet ned' : 'Ikke lastet ned',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDownloaded
                          ? const Color(0xFF2E7D32)
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Row(
            //   children: [
            //     Icon(
            //       Icons.calendar_today_outlined,
            //       size: 14,
            //       color: Colors.grey[600],
            //     ),
            //     const SizedBox(width: 6),
            //     Text(
            //       'Versjon: ${_formatDate(publication.updateDate)}',
            //       style: TextStyle(
            //         fontSize: 13,
            //         color: Colors.grey[600],
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(height: 4),
            // Row(
            //   children: [
            //     Icon(
            //       Icons.tag,
            //       size: 14,
            //       color: Colors.grey[600],
            //     ),
            //     const SizedBox(width: 6),
            //     Expanded(
            //       child: Text(
            //         'ID: ${publication.id}',
            //         style: TextStyle(
            //           fontSize: 11,
            //           color: Colors.grey[600],
            //           fontFamily: 'monospace',
            //         ),
            //         overflow: TextOverflow.ellipsis,
            //       ),
            //     ),
            //   ],
            // ),
            if (!isDownloaded) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadPublication(publication),
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text(
                    'Last ned',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0974ba),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            if (isDownloaded && hasUpdate) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadPublication(publication),
                  icon: const Icon(Icons.system_update, size: 20),
                  label: const Text(
                    'Oppdater',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            if (isDownloaded) ...[
              SizedBox(height: hasUpdate ? 8 : 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openPublication(publication),
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  label: const Text(
                    'Åpne',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0974ba),
                    side: const BorderSide(
                      color: Color(0xFF0974ba),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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

  bool _hasUpdate(Publication publication) {
    if (publication.newVersionDate == null) return false;
    return publication.newVersionDate!.isAfter(publication.updateDate);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Ukjent';
    return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadPublication(Publication publication) async {
    print('🔍 === DOWNLOAD BUTTON CLICKED ===');
    print('📦 Publication ID: "${publication.id}"');
    print('📦 Publication Name: "${publication.name}"');
    print('📦 ID Type: ${publication.id.runtimeType}');
    print('📦 ID Length: ${publication.id.length}');
    print('📦 ID Bytes: ${publication.id.codeUnits}');
    print('📦 ID trimmed: "${publication.id.trim()}"');
    print('📦 ID contains whitespace: ${publication.id.contains(' ')}');

    bool cancelled = false;
    double progress = 0.0;
    String statusText = 'Forbereder nedlasting...';
    late StateSetter dialogSetState;
    bool dialogClosed = false;

    void closeDialog() {
      dialogClosed = true;
      if (mounted) {
        try {
          final navigator = Navigator.of(context, rootNavigator: true);
          if (navigator.canPop()) {
            navigator.pop();
          }
        } catch (e) {
          try {
            Navigator.of(context).pop();
          } catch (e2) {}
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;
          return AlertDialog(
            title: const Text('Laster ned publikasjon'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('${(progress * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(statusText),
                const SizedBox(height: 8),
                Text(publication.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center),
                // if (publication.dataSizeInBytes != null) ...[
                //   const SizedBox(height: 4),
                //   Text(
                //       'Størrelse: ${_formatDataSize(publication.dataSizeInBytes!)}',
                //       style: const TextStyle(fontSize: 11, color: Colors.grey)),
                // ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancelled = true;
                  dialogClosed = true;
                  try {
                    if (Navigator.of(dialogContext).canPop()) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (e) {
                    try {
                      Navigator.of(context).pop();
                    } catch (e2) {}
                  }
                },
                child: const Text('Avbryt'),
              ),
            ],
          );
        },
      ),
    );

    try {
      await Future.delayed(const Duration(milliseconds: 100));
      if (cancelled || dialogClosed) return;
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
            } catch (e) {}
          }
        },
      );
      if (cancelled || dialogClosed || !mounted) return;

      // Keep progress dialog open and update status
      if (!cancelled && !dialogClosed && mounted) {
        try {
          dialogSetState(() {
            progress = 1.0;
            statusText = 'Oppdaterer publikasjonsliste...';
          });
        } catch (e) {}
      }

      if (mounted) {
        // Update publication's updateDate after successful download
        await _updatePublicationAfterDownload(publication.id);

        // Reload publications list
        await _loadPublications();

        // Now close progress dialog
        closeDialog();
        await Future.delayed(const Duration(milliseconds: 100));

        // Show success dialog after everything is complete
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Nedlasting fullført'),
                ],
              ),
              content: Text(
                  '${publication.name} er lastet ned med bilder og er klar til bruk.'),
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
    } catch (e) {
      if (cancelled || dialogClosed) return;
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
        // Show error dialog instead of snackbar
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('Feil ved nedlasting'),
              ],
            ),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Avbryt'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _downloadPublication(publication);
                },
                child: const Text('Prøv igjen'),
              ),
            ],
          ),
        );
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
