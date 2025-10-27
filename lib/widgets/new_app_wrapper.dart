import 'package:flutter/material.dart';
import '../main.dart';
import '../services/new_user_data_service.dart';
import '../services/new_publication_service.dart';
import '../screens/new_publication_list_screen.dart';
import '../screens/new_my_page_screen.dart';
import '../models/new_publication.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NewAppWrapper extends StatefulWidget {
  const NewAppWrapper({super.key});

  @override
  State<NewAppWrapper> createState() => _NewAppWrapperState();
}

class _NewAppWrapperState extends State<NewAppWrapper> {
  final UserDataService _userDataService = UserDataService.instance;
  final NewPublicationService _publicationService =
      NewPublicationService.instance;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAfterLogin();
  }

  Future<void> _initializeAfterLogin() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get user info from UserSession
      final userSession = UserSession.instance;
      final userEmail = userSession.userEmail;
      final extensionProducts = userSession.extensionProducts;

      if (userEmail == null ||
          extensionProducts == null ||
          extensionProducts.isEmpty) {
        setState(() {
          _errorMessage = 'Manglende brukerinformasjon. Logg inn på nytt.';
          _isLoading = false;
        });
        return;
      }

      print('🔑 Initializing app for user: $userEmail');
      print('🔑 Extension products: $extensionProducts');

      // First, try to load existing user data
      try {
        final existingUserData = await _userDataService.loadUserData();
        if (existingUserData != null &&
            existingUserData.email == userEmail &&
            existingUserData.availablePublications.isNotEmpty) {
          print(
              '✅ Using existing user data with ${existingUserData.availablePublications.length} publications');
          setState(() {
            _isLoading = false;
          });

          // Check for updates after loading existing data
          if (mounted) {
            _checkForUpdatesOnAppStart();
          }
          return;
        }
      } catch (e) {
        print('📝 No existing user data found: $e');
      }

      // If no existing data, try to fetch from API
      try {
        final publications = await _publicationService.fetchPublications();
        print('📚 Fetched ${publications.length} publications from API');

        // Create user data
        final userData = await _userDataService.createUserData(
          email: userEmail,
          extensionProducts: extensionProducts,
          publications: publications,
        );

        print(
            '✅ User data created with ${userData.availablePublications.length} accessible publications');

        setState(() {
          _isLoading = false;
        });

        // Check for updates after initialization if we have internet
        if (mounted) {
          _checkForUpdatesOnAppStart();
        }
      } catch (e) {
        print('❌ Error fetching publications from API: $e');

        // As a last resort, create minimal user data with hardcoded publications
        try {
          print('🔄 Creating fallback user data...');
          final fallbackPublications = [
            Publication(
              id: '1',
              name: 'Prenøk',
              title: 'Prenøk',
              createDate: DateTime.now(),
              updateDate: DateTime.now(),
              restrictPublicAccessIds: ['b0429ab1-b47c-473f-8ec3-08dc9c1adbcb'],
            ),
            Publication(
              id: '2',
              name: 'Rørhåndboka 2024 Pluss',
              title: 'Rørhåndboka 2024 Pluss',
              createDate: DateTime.now(),
              updateDate: DateTime.now(),
              restrictPublicAccessIds: ['b0429ab1-b47c-473f-8ec3-08dc9c1adbcb'],
            ),
          ];

          final userData = await _userDataService.createUserData(
            email: userEmail,
            extensionProducts: extensionProducts,
            publications: fallbackPublications,
          );

          print(
              '✅ Fallback user data created with ${userData.availablePublications.length} publications');

          setState(() {
            _isLoading = false;
          });

          // Check for updates after fallback data creation
          if (mounted) {
            _checkForUpdatesOnAppStart();
          }
        } catch (fallbackError) {
          print('❌ Error creating fallback data: $fallbackError');
          setState(() {
            _errorMessage =
                'Kunne ikke hente publikasjoner. Sjekk internettforbindelsen.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error initializing app: $e');
      setState(() {
        _errorMessage = 'Feil ved oppstart av appen: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkForUpdatesOnAppStart() async {
    try {
      print('🔄 Starting update check on app start...');

      // Check internet connectivity
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasInternet = connectivityResults.isNotEmpty &&
          !connectivityResults
              .every((result) => result == ConnectivityResult.none);

      print('📶 Internet check result: ${hasInternet ? 'Online' : 'Offline'}');

      if (!hasInternet) {
        print('📶 No internet connection - skipping update check popup');
        return;
      }

      // Small delay to ensure the main screen has loaded
      print('⏳ Waiting 500ms for UI to load...');
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) {
        print('❌ Widget not mounted - skipping popup');
        return;
      }

      print('📱 Showing update check popup...');

      // Show update check popup
      final shouldCheckUpdates = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Sjekk for oppdateringer'),
          content: const Text(
            'For å sjekke om det finnes nye versjoner av publikasjonene dine, kan du trykke på Oppdater på Publikasjoner sida!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Ok'),
            ),
          ],
        ),
      );

      print('👆 User response: ${shouldCheckUpdates == true ? 'Yes' : 'No'}');

      if (shouldCheckUpdates == true && mounted) {
        print('🧭 Navigating to My Page...');
        // Navigate to My Page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const NewMyPageScreen(),
          ),
        );

        // Show a snackbar with instructions after navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Trykk på "Oppdater" nederst på siden for å sjekke etter nye versjoner',
                ),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.blue,
              ),
            );
          }
        });
      }
    } catch (e) {
      print('❌ Error checking for updates on app start: $e');
      // Don't show error to user - just continue with normal app flow
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kompetansebiblioteket',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0974ba),
          primary: const Color(0xFF0974ba),
        ),
        useMaterial3: true,
      ),
      home: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Laster...'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initialiserer appen...'),
              SizedBox(height: 8),
              Text(
                'Henter publikasjoner og setter opp brukerkonto',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Feil'),
          backgroundColor: Colors.red[100],
        ),
        body: Center(
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
                  'Feil ved oppstart',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _initializeAfterLogin,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Prøv igjen'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await UserSession.instance.clearSession();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const AuthWrapper(),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logg ut'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Navigate to publications screen (main screen after login)
    return const NewPublicationListScreen();
  }

  @override
  void dispose() {
    _publicationService.dispose();
    super.dispose();
  }
}
