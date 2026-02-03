import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'widgets/new_app_wrapper.dart';
import 'package:aad_b2c_webview/aad_b2c_webview.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
// import 'services/update_check_service.dart'; // Disabled background updates

// Singleton for storing user session information with persistent storage
class UserSession {
  static final UserSession _instance = UserSession._internal();
  static UserSession get instance => _instance;
  UserSession._internal();

  String? idToken;
  String? accessToken;
  String? refreshToken;
  String? userEmail;
  String? userName;
  List<String>? extensionProducts;
  List<Map<String, dynamic>>?
      extensionProductsData; // Full product data with dates
  bool _isInitialized = false;

  // Initialize session from persistent storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    idToken = prefs.getString('idToken');
    accessToken = prefs.getString('accessToken');
    refreshToken = prefs.getString('refreshToken');
    userEmail = prefs.getString('userEmail');
    userName = prefs.getString('userName');

    // Load extension products from persistent storage
    final productsString = prefs.getString('extensionProducts');
    if (productsString != null) {
      extensionProducts =
          productsString.split(',').where((s) => s.isNotEmpty).toList();
    }

    // Load full extension products data with dates
    final productsDataString = prefs.getString('extensionProductsData');
    if (productsDataString != null) {
      try {
        final decoded = json.decode(productsDataString);
        if (decoded is List) {
          extensionProductsData = decoded.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        print('Error loading extensionProductsData: $e');
      }
    }

    _isInitialized = true;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    await initialize();
    // User is logged in if they have either a valid token OR saved extension products
    return (idToken != null && idToken!.isNotEmpty) ||
        (extensionProducts != null && extensionProducts!.isNotEmpty);
  }

  // Update tokens and save to persistent storage
  Future<void> updateTokens({
    String? idToken,
    String? accessToken,
    String? refreshToken,
    String? userEmail,
    String? userName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (idToken != null) {
      this.idToken = idToken;
      await prefs.setString('idToken', idToken);

      // Decode token and extract extension_Products
      try {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(idToken);
        print('=== USER SESSION DEBUG ===');
        print('Decoded token keys: ${decodedToken.keys.toList()}');
        print(
            'extension_Products value: ${decodedToken['extension_Products']}');

        if (decodedToken['extension_Products'] != null) {
          final productsValue = decodedToken['extension_Products'];
          print('Raw extension_Products value: $productsValue');
          print('Type: ${productsValue.runtimeType}');

          List<Map<String, dynamic>> fullProductsData = [];

          if (productsValue is String) {
            try {
              // Try to parse as JSON first (in case it's a JSON string)
              final parsed = json.decode(productsValue);
              if (parsed is List) {
                extensionProducts = parsed.map((item) {
                  if (item is Map<String, dynamic> && item['Id'] != null) {
                    fullProductsData.add(Map<String, dynamic>.from(item));
                    return item['Id'].toString();
                  } else {
                    return item.toString();
                  }
                }).toList();
                print(
                    'Parsed extension products from JSON string: $extensionProducts');
              } else {
                extensionProducts = [parsed.toString()];
                print(
                    'Parsed single extension product from JSON: $extensionProducts');
              }
            } catch (e) {
              // If JSON parsing fails, treat as comma-separated string
              extensionProducts =
                  productsValue.split(',').map((e) => e.trim()).toList();
              print(
                  'Parsed extension products from comma-separated string: $extensionProducts');
            }
          } else if (productsValue is List) {
            extensionProducts = productsValue.map((item) {
              if (item is Map<String, dynamic> && item['Id'] != null) {
                fullProductsData.add(Map<String, dynamic>.from(item));
                return item['Id'].toString();
              } else {
                return item.toString();
              }
            }).toList();
            print('Parsed extension products from list: $extensionProducts');
          }

          // Store full product data with dates
          extensionProductsData = fullProductsData;
          print('Full extension products data: $extensionProductsData');

          // Save to persistent storage
          await prefs.setString(
              'extensionProducts', extensionProducts?.join(',') ?? '');
          await prefs.setString(
              'extensionProductsData', json.encode(fullProductsData));
          print(
              'Saved extension products to storage: ${extensionProducts?.join(',')}');
        } else {
          print('No extension_Products found in token');
        }
        print('=== END USER SESSION DEBUG ===');
      } catch (e) {
        print('Error decoding token for extension products: $e');
      }
    }
    if (accessToken != null) {
      this.accessToken = accessToken;
      await prefs.setString('accessToken', accessToken);
    }
    if (refreshToken != null) {
      this.refreshToken = refreshToken;
      await prefs.setString('refreshToken', refreshToken);
    }
    if (userEmail != null) {
      this.userEmail = userEmail;
      await prefs.setString('userEmail', userEmail);
    }
    if (userName != null) {
      this.userName = userName;
      await prefs.setString('userName', userName);
    }
  }

  // Clear session and remove from persistent storage
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    idToken = null;
    accessToken = null;
    refreshToken = null;
    userEmail = null;
    userName = null;
    extensionProducts = null;
    extensionProductsData = null;

    await prefs.remove('idToken');
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('extensionProducts');
    await prefs.remove('extensionProductsData');
  }

  // Debug method to check what's persisted
  Future<Map<String, dynamic>> getDebugInfo() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();

    return {
      'session_extensionProducts': extensionProducts,
      'session_extensionProductsData': extensionProductsData,
      'storage_extensionProducts': prefs.getString('extensionProducts'),
      'storage_extensionProductsData': prefs.getString('extensionProductsData'),
      'session_userEmail': userEmail,
      'session_isLoggedIn': await isLoggedIn(),
      'has_idToken': idToken != null && idToken!.isNotEmpty,
    };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LoadingApp());

  // Initialize dependencies and user session
  await Injections.initialize();
  await UserSession.instance.initialize();

  // Switch to main app after initialization
  runApp(const MyApp());
}

class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kompetansebiblioteket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0974ba),
          primary: const Color(0xFF0974ba),
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0974ba), // App theme color
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon could go here
              const SizedBox(height: 24),
              const Text(
                'Kompetansebiblioteket',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Laster...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kompetansebiblioteket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0974ba),
          primary: const Color(0xFF0974ba),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await UserSession.instance.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });

    // Background update checking disabled for now
    // if (isLoggedIn && mounted) {
    //   UpdateCheckService.instance.startBackgroundChecking(context);
    // }
  }

  @override
  void dispose() {
    // Background update checking disabled
    // UpdateCheckService.instance.stopBackgroundChecking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn) {
      return const NewAppWrapper();
    } else {
      return const HomePage();
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userEmail;
  String? _userName;
  bool _isCheckingConnectivity = false;

  Future<void> _checkConnectivityAndLogin() async {
    setState(() {
      _isCheckingConnectivity = true;
    });

    try {
      print('🌐 Checking network connectivity before login...');
      // Check if device is connected to a network
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      print('🌐 Network status: $result');

      if (result == ConnectivityResult.none) {
        print('❌ No network connection detected');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Ingen internettforbindelse. Sjekk nettverksinnstillingene.'),
          ),
        );
        setState(() {
          _isCheckingConnectivity = false;
        });
        return;
      }

      // Then test actual internet connectivity by pinging a reliable host
      try {
        print('🌐 Testing internet connectivity with google.com...');
        final lookupResult = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));

        final hasInternet =
            lookupResult.isNotEmpty && lookupResult[0].rawAddress.isNotEmpty;
        print('🌐 Google.com lookup result: $hasInternet');

        if (hasInternet) {
          // Proceed with login
          _performLogin();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ingen internettilgang. Prøv igjen senere.'),
            ),
          );
        }
      } catch (e) {
        print('⚠️ Google.com failed: $e, trying Azure domain...');
        // If google.com fails, try the Azure login domain directly
        try {
          final azureLookup =
              await InternetAddress.lookup('nemiteks4prod.b2clogin.com')
                  .timeout(const Duration(seconds: 5));

          final hasAzureAccess =
              azureLookup.isNotEmpty && azureLookup[0].rawAddress.isNotEmpty;
          print('🌐 Azure domain lookup result: $hasAzureAccess');

          if (hasAzureAccess) {
            // Proceed with login
            _performLogin();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Kan ikke nå påloggingstjenesten. Prøv igjen senere.'),
              ),
            );
          }
        } catch (e2) {
          print('❌ Azure domain also failed: $e2');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Kan ikke nå påloggingstjenesten. Prøv igjen senere.'),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Connectivity check failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feil ved nettverkssjekk. Prøv igjen.'),
        ),
      );
    }

    setState(() {
      _isCheckingConnectivity = false;
    });
  }

  void _performLogin() {
    // Azure AD B2C Configuration
    // Note: Using custom URL scheme for redirect. Make sure this matches
    // the redirect URL configured in Azure AD B2C portal.
    final params = B2CWebViewParams(
      responseType: 'code',
      tenantBaseUrl:
          'https://nemiteks4prod.b2clogin.com/nemiteks4prod.onmicrosoft.com',
      clientId: '49eb6aeb-650f-4da9-967b-bb39d8b7ebd0',
      userFlowName: 'B2C_1_signin',
      redirectUrl: 'myapp://auth',
      scopes: ['openid', 'offline_access', 'profile'],
      containsChallenge: true,
      isLoginFlow: true,
    );

    print('🔐 Starting Azure AD B2C login flow...');
    print('🔐 Redirect URL: ${params.redirectUrl}');
    print('🔐 Platform: ${Platform.isIOS ? "iOS" : "Android"}');

    // Navigate to full-screen login page for better iOS compatibility
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _B2CLoginScreen(
          params: params,
          onSuccess: _onLoginSuccess,
          onError: _onLoginError,
        ),
      ),
    );
  }

  Future<void> _onLoginSuccess(
    BuildContext context,
    accessToken,
    idToken,
    refreshToken,
  ) async {
    // Close the login dialog
    Navigator.of(context).pop();

    if (idToken != null && idToken.value != null) {
      try {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(idToken.value!);
        final userEmail = decodedToken['email'] ??
            decodedToken['emails']?.first ??
            'Ikke funnet';
        final userName =
            decodedToken['name'] ?? decodedToken['given_name'] ?? 'Ikke funnet';

        // Store in UserSession for global access with persistent storage
        await UserSession.instance.updateTokens(
          idToken: idToken.value,
          accessToken: accessToken.value,
          refreshToken: refreshToken?.value,
          userEmail: userEmail,
          userName: userName,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Innlogget som: $userEmail')),
        );

        // Navigate to new app wrapper
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const NewAppWrapper(),
          ),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Innlogging vellykket, men kunne ikke hente brukerinfo'),
          ),
        );
      }
    }
  }

  void _onLoginError(BuildContext context, String? error) {
    print('🔐 === LOGIN ERROR DEBUG ===');
    print('🔐 Raw error: $error');
    print('🔐 Platform: ${Platform.isIOS ? "iOS" : "Android"}');
    print('🔐 === END LOGIN ERROR DEBUG ===');

    // Close the login dialog if it's still open
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Parse error message and provide better feedback
    String displayError;
    if (error == null || error.isEmpty) {
      displayError = 'Ukjent feil ved innlogging';
    } else if (error.contains('problemer med å logge deg på') ||
        error.toLowerCase().contains('error') ||
        error.toLowerCase().contains('failed')) {
      // This error typically comes from Azure B2C when:
      // 1. The redirect URL handling fails
      // 2. The token exchange fails
      // 3. Network issues during authentication
      displayError =
          'Innlogging feilet. Vennligst lukk appen helt og prøv igjen. '
          'Hvis problemet vedvarer, sjekk internettforbindelsen.';
      print(
          '🔐 Hint: If this persists on iOS simulator, try testing on a real device');
    } else {
      displayError = error;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Innlogging feilet: $displayError'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Prøv igjen',
          onPressed: () {
            _checkConnectivityAndLogin();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0974ba),
              const Color.fromARGB(255, 83, 94, 101).withOpacity(0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/kompetansebiblioteket_logo.png',
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          children: [
                            Icon(
                              Icons.library_books,
                              size: 80,
                              color: const Color(0xFF0974ba),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Kompetansebiblioteket',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0974ba),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Welcome text
                  const Text(
                    'Velkommen',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Logg inn for å få tilgang til dine publikasjoner',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  // User info card (if logged in previously)
                  if (_userEmail != null) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0974ba).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: const Color(0xFF0974ba),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tidligere innlogget som:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userName ?? 'Ukjent',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1a1a1a),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail ?? 'Ukjent',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Login button
                  _isCheckingConnectivity
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _checkConnectivityAndLogin,
                            icon: const Icon(Icons.login, size: 22),
                            label: Text(
                              _userEmail != null
                                  ? 'Logg inn på nytt'
                                  : 'Logg inn',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0974ba),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.3),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 48),
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF0974ba).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0974ba).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.contact_support,
                                color: Color(0xFF0974ba),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Trenger du hjelp?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1a1a1a),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ønsker du å bestille flere publikasjoner eller lisenser? Ta kontakt med vår kundeservice på:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0974ba).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.email,
                                size: 18,
                                color: Color(0xFF0974ba),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'kundeservice@nemitek.no',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0974ba),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Wrapper for B2C login that can be called from hamburger menu
class B2CLoginPageWrapper extends StatefulWidget {
  const B2CLoginPageWrapper({super.key});

  @override
  State<B2CLoginPageWrapper> createState() => _B2CLoginPageWrapperState();
}

class _B2CLoginPageWrapperState extends State<B2CLoginPageWrapper> {
  bool _isCheckingConnectivity = true;
  bool _hasConnection = false;

  @override
  void initState() {
    super.initState();
    print('🌐 B2CLoginPageWrapper: Checking connectivity before login...');
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    try {
      print('🌐 Checking network connectivity...');
      // First check if device is connected to a network
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      print('🌐 Network status: $result');

      if (result == ConnectivityResult.none) {
        print('❌ No network connection detected');
        setState(() {
          _hasConnection = false;
          _isCheckingConnectivity = false;
        });
        return;
      }

      // Then test actual internet connectivity by pinging a reliable host
      try {
        print('🌐 Testing internet connectivity with google.com...');
        final lookupResult = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));

        final hasInternet =
            lookupResult.isNotEmpty && lookupResult[0].rawAddress.isNotEmpty;
        print('🌐 Google.com lookup result: $hasInternet');

        setState(() {
          _hasConnection = hasInternet;
          _isCheckingConnectivity = false;
        });
      } catch (e) {
        print('⚠️ Google.com failed: $e, trying Azure domain...');
        // If google.com fails, try the Azure login domain directly
        try {
          final azureLookup =
              await InternetAddress.lookup('nemiteks4prod.b2clogin.com')
                  .timeout(const Duration(seconds: 5));

          final hasAzureAccess =
              azureLookup.isNotEmpty && azureLookup[0].rawAddress.isNotEmpty;
          print('🌐 Azure domain lookup result: $hasAzureAccess');

          setState(() {
            _hasConnection = hasAzureAccess;
            _isCheckingConnectivity = false;
          });
        } catch (e2) {
          print('❌ Azure domain also failed: $e2');
          setState(() {
            _hasConnection = false;
            _isCheckingConnectivity = false;
          });
        }
      }
    } catch (e) {
      print('❌ Connectivity check failed: $e');
      setState(() {
        _hasConnection = false;
        _isCheckingConnectivity = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingConnectivity) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Logger inn'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Sjekker internettforbindelse...'),
            ],
          ),
        ),
      );
    }

    if (!_hasConnection) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ingen internettforbindelse'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 80,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                Text(
                  'Ingen internettforbindelse',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Du må være koblet til internett for å logge inn med Azure AD.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sjekk at du har:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '• WiFi eller mobildata aktivert\n• Stabil internettforbindelse\n• Tilgang til eksterne nettsteder',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
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
                        setState(() {
                          _isCheckingConnectivity = true;
                        });
                        _checkConnectivity();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Prøv igjen'),
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
        ),
      );
    }

    // Azure AD B2C Configuration
    final params = B2CWebViewParams(
      responseType: 'code',
      tenantBaseUrl:
          'https://nemiteks4prod.b2clogin.com/nemiteks4prod.onmicrosoft.com',
      clientId: '49eb6aeb-650f-4da9-967b-bb39d8b7ebd0',
      userFlowName: 'B2C_1_signin',
      redirectUrl: 'myapp://auth',
      scopes: ['openid', 'offline_access', 'profile'],
      containsChallenge: true,
      isLoginFlow: true,
    );

    return B2CLoginPage(
      params: params,
      onSuccess: _onLoginSuccess,
      onError: _onLoginError,
    );
  }

  Future<void> _onLoginSuccess(
    BuildContext context,
    accessToken,
    idToken,
    refreshToken,
  ) async {
    if (idToken != null && idToken.value != null) {
      try {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(idToken.value!);
        final userEmail = decodedToken['email'] ??
            decodedToken['emails']?.first ??
            'Ikke funnet';
        final userName =
            decodedToken['name'] ?? decodedToken['given_name'] ?? 'Ikke funnet';

        // Store in UserSession for global access with persistent storage
        await UserSession.instance.updateTokens(
          idToken: idToken.value,
          accessToken: accessToken.value,
          refreshToken: refreshToken?.value,
          userEmail: userEmail,
          userName: userName,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Innlogget som: $userEmail')),
        );

        // Navigate to new app wrapper
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const NewAppWrapper(),
          ),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Innlogging vellykket, men kunne ikke hente brukerinfo'),
          ),
        );
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _onLoginError(BuildContext context, String? error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Innlogging feilet: ${error ?? 'Ukjent feil'}'),
      ),
    );
    Navigator.pop(context);
  }
}

// Full-screen login screen using native webview_flutter for iOS compatibility
class _B2CLoginScreen extends StatefulWidget {
  final B2CWebViewParams params;
  final Function(BuildContext, dynamic, dynamic, dynamic) onSuccess;
  final Function(BuildContext, String?) onError;

  const _B2CLoginScreen({
    required this.params,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_B2CLoginScreen> createState() => _B2CLoginScreenState();
}

class _B2CLoginScreenState extends State<_B2CLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasHandledRedirect = false;
  late final PkcePair _pkcePair;
  late final String _authUrl;

  @override
  void initState() {
    super.initState();
    _initializeLogin();
  }

  Future<void> _initializeLogin() async {
    // Generate PKCE code verifier and challenge - must be unique for each login attempt
    _pkcePair = PkcePair.generate();

    // Build the authorization URL with a unique state parameter to prevent caching issues
    final baseUrl = widget.params.tenantBaseUrl;
    final clientId = widget.params.clientId;
    final redirectUrl = widget.params.redirectUrl;
    final userFlow = widget.params.userFlowName;
    final scopes = widget.params.scopes.join(' ');
    final uniqueState = DateTime.now().millisecondsSinceEpoch.toString();

    _authUrl = '$baseUrl/$userFlow/oauth2/v2.0/authorize?'
        'client_id=$clientId&'
        'response_type=code&'
        'redirect_uri=${Uri.encodeComponent(redirectUrl)}&'
        'scope=${Uri.encodeComponent(scopes)}&'
        'code_challenge=${_pkcePair.codeChallenge}&'
        'code_challenge_method=S256&'
        'response_mode=query&'
        'state=$uniqueState&'
        'prompt=login'; // Force fresh login

    print('🔐 Auth URL: $_authUrl');
    print('🔐 PKCE code_challenge: ${_pkcePair.codeChallenge}');

    // Initialize WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('🔐 Page started: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            print('🔐 Page finished: $url');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            print('🔐 Navigation request: ${request.url}');

            // Check if this is the redirect URL with auth code
            if (request.url.startsWith(widget.params.redirectUrl)) {
              print('🔐 Detected redirect URL!');
              _handleRedirect(request.url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            print('🔐 WebResource error: ${error.description}');
            // Don't treat custom scheme navigation as error
            if (!error.description.contains('myapp://')) {
              if (!_hasHandledRedirect && mounted) {
                _hasHandledRedirect = true;
                widget.onError(context, error.description);
              }
            }
          },
        ),
      );

    // Clear cookies and cache before loading to ensure fresh login
    await _controller.clearCache();
    await _controller.clearLocalStorage();

    print('🔐 Cleared WebView cache and storage');

    // Load the auth URL
    await _controller.loadRequest(Uri.parse(_authUrl));
  }

  Future<void> _handleRedirect(String url) async {
    if (_hasHandledRedirect) return;
    _hasHandledRedirect = true;

    print('🔐 Handling redirect: $url');

    try {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];
      final errorDescription = uri.queryParameters['error_description'];

      if (error != null) {
        print('🔐 Auth error: $error - $errorDescription');
        if (mounted) {
          widget.onError(context, errorDescription ?? error);
        }
        return;
      }

      if (code == null) {
        print('🔐 No code in redirect URL');
        if (mounted) {
          widget.onError(context, 'Ingen autorisasjonskode mottatt');
        }
        return;
      }

      print('🔐 Got authorization code, exchanging for tokens...');

      // Exchange code for tokens
      final tokens = await _exchangeCodeForTokens(code);

      if (tokens != null && mounted) {
        print('🔐 Token exchange successful!');
        widget.onSuccess(
          context,
          _TokenWrapper(tokens['access_token']),
          _TokenWrapper(tokens['id_token']),
          _TokenWrapper(tokens['refresh_token']),
        );
      } else if (mounted) {
        widget.onError(context, 'Kunne ikke utveksle token');
      }
    } catch (e) {
      print('🔐 Error handling redirect: $e');
      if (mounted) {
        widget.onError(context, 'Feil ved innlogging: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _exchangeCodeForTokens(String code) async {
    try {
      final tokenUrl =
          '${widget.params.tenantBaseUrl}/${widget.params.userFlowName}/oauth2/v2.0/token';

      print('🔐 Token endpoint: $tokenUrl');

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': widget.params.clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': widget.params.redirectUrl,
          'code_verifier': _pkcePair.codeVerifier,
          'scope': widget.params.scopes.join(' '),
        },
      );

      print('🔐 Token response status: ${response.statusCode}');
      print('🔐 Token response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        print('🔐 Token error: ${errorBody['error_description']}');
        return null;
      }
    } catch (e) {
      print('🔐 Token exchange error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logg inn'),
        backgroundColor: const Color(0xFF0974ba),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF0974ba),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Laster innlogging...',
                      style: TextStyle(
                        color: Color(0xFF0974ba),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Simple wrapper class to mimic the token structure from aad_b2c_webview
class _TokenWrapper {
  final String? value;
  _TokenWrapper(this.value);
}

// Separate login page using aad_b2c_webview (kept for backward compatibility)
class B2CLoginPage extends StatelessWidget {
  final B2CWebViewParams params;
  final Function(BuildContext, dynamic, dynamic, dynamic) onSuccess;
  final Function(BuildContext, String?) onError;

  const B2CLoginPage({
    super.key,
    required this.params,
    required this.onSuccess,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Azure AD B2C Login'),
        backgroundColor: const Color(0xFF2196f3),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Azure B2C Login',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32.0),
              AADB2CBase.button(
                params: params,
                settings: ButtonSettingsEntity(
                  onError: onError,
                  onSuccess: onSuccess,
                  onKeepLoading: (String? url) =>
                      url?.startsWith(params.redirectUrl) ?? false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
