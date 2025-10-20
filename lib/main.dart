import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'widgets/main_scaffold.dart';
import 'widgets/new_app_wrapper.dart';
import 'package:aad_b2c_webview/aad_b2c_webview.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

          if (productsValue is String) {
            try {
              // Try to parse as JSON first (in case it's a JSON string)
              final parsed = json.decode(productsValue);
              if (parsed is List) {
                extensionProducts = parsed.map((item) {
                  if (item is Map<String, dynamic> && item['Id'] != null) {
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
                return item['Id'].toString();
              } else {
                return item.toString();
              }
            }).toList();
            print('Parsed extension products from list: $extensionProducts');
          }

          // Save to persistent storage
          await prefs.setString(
              'extensionProducts', extensionProducts?.join(',') ?? '');
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

    await prefs.remove('idToken');
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('extensionProducts');
  }

  // Debug method to check what's persisted
  Future<Map<String, dynamic>> getDebugInfo() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();

    return {
      'session_extensionProducts': extensionProducts,
      'storage_extensionProducts': prefs.getString('extensionProducts'),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196f3),
          primary: const Color(0xFF2196f3),
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF2196f3), // App theme color
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196f3),
          primary: const Color(0xFF2196f3),
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
      // First check if device is connected to a network
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

    // Show the Azure AD B2C login directly in a dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Logger inn...',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20.0),
                AADB2CBase.button(
                  params: params,
                  settings: ButtonSettingsEntity(
                    onError: _onLoginError,
                    onSuccess: _onLoginSuccess,
                    onKeepLoading: (String? url) =>
                        url?.startsWith(params.redirectUrl) ?? false,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    // Close the login dialog
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Innlogging feilet: ${error ?? 'Ukjent feil'}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Hjem',
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Kompetansebiblioteket',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196f3),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_userEmail != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Innlogget som:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Navn: $_userName'),
                      Text('E-post: $_userEmail'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _isCheckingConnectivity
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _checkConnectivityAndLogin,
                    child: Text(
                      _userEmail != null ? 'Logg inn på nytt' : 'Logg inn',
                    ),
                  ),
          ],
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
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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

// Separate login page using aad_b2c_webview
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
