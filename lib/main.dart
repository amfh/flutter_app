import 'package:flutter/material.dart';
import 'dart:convert';
import 'screens/publication_list_screen.dart';
import 'widgets/main_scaffold.dart';
import 'package:aad_b2c_webview/aad_b2c_webview.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  await Injections.initialize();
  await UserSession.instance.initialize();
  runApp(const MyApp());
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
      return const PublicationListScreen();
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

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Hjem',
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
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
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const B2CLoginPageWrapper(),
                  ),
                );
              },
              child: Text(
                _userEmail != null ? 'Logg inn på nytt' : 'Logg inn',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PublicationListScreen(),
                  ),
                );
              },
              child: const Text('Gå til publikasjoner'),
            ),
          ],
        ),
      ),
    );
  }
}

// Wrapper for B2C login that can be called from hamburger menu
class B2CLoginPageWrapper extends StatelessWidget {
  const B2CLoginPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
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

        // Navigate to main app screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const PublicationListScreen(),
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
