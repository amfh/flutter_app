import 'package:flutter/material.dart';
import 'screens/publication_list_screen.dart';
import 'widgets/main_scaffold.dart';
import 'widgets/subchapter_search_bar.dart';
import 'package:aad_b2c_webview/aad_b2c_webview.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Injections.initialize();
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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _accessToken;
  String? _userEmail;
  String? _userName;

  // Azure AD B2C Configuration
  late final B2CWebViewParams params = B2CWebViewParams(
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

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => B2CLoginPage(
          params: params,
          onSuccess: _onLoginSuccess,
          onError: _onLoginError,
        ),
      ),
    );
  }

  void _onLoginSuccess(
    BuildContext context,
    accessToken,
    idToken,
    refreshToken,
  ) {
    setState(() {
      _accessToken = accessToken.value;
    });

    if (idToken != null && idToken.value != null) {
      try {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(idToken.value!);
        setState(() {
          _userEmail = decodedToken['email'] ??
              decodedToken['emails']?.first ??
              'Ikke funnet';
          _userName = decodedToken['name'] ??
              decodedToken['given_name'] ??
              'Ikke funnet';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Innlogget som: $_userEmail')),
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

    Navigator.pop(context);
  }

  void _onLoginError(BuildContext context, String? error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Innlogging feilet: ${error ?? 'Ukjent feil'}'),
      ),
    );
    Navigator.pop(context);
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
              onPressed: _navigateToLogin,
              child: Text(
                _userEmail != null ? 'Logg inn på nytt' : 'Logg inn med B2C',
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
