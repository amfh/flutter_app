import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/new_main_scaffold.dart';
import '../services/new_user_data_service.dart';
import '../services/new_publication_service.dart';
import '../models/user_data.dart';

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
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(),
            const SizedBox(height: 16),
            _buildSubscriptionsCard(),
            const SizedBox(height: 16),
            _buildLogoutCard(),
          ],
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
                  'Sist pålogging: ',
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

  Widget _buildLogoutCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.logout,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Logg ut',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const Text(
              'Mangler du abonnement eller har fått nytt abonnement? Logg ut og inn igjen på appen.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logg ut'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logg ut'),
          content: const Text('Er du sikker på at du vil logge ut?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _performLogout();
              },
              child: const Text('Logg ut'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      // Clear user session
      await UserSession.instance.clearSession();

      // Delete local user data (but keep downloaded publications for offline use)
      await _userDataService.deleteUserData();

      // NOTE: We do NOT clear downloaded content to preserve offline publications
      // If you want to clear content on logout, uncomment the line below:
      // await _publicationService.clearAllContent();

      if (mounted) {
        // Navigate back to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthWrapper(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Error during logout: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feil under utlogging. Prøv igjen.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  @override
  void dispose() {
    _publicationService.dispose();
    super.dispose();
  }
}
