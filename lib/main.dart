import 'package:flutter/material.dart';
import 'screens/publication_list_screen.dart';
import 'widgets/main_scaffold.dart';
import 'widgets/subchapter_search_bar.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

void main() {
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
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  String? _accessToken;
  String? _userEmail;
  String? _userName;

  Future<void> _login(BuildContext context) async {
    try {
      const String clientId = '49eb6aeb-650f-4da9-967b-bb39d8b7ebd0';
      const String redirectUri = 'myapp://auth';

      const AuthorizationServiceConfiguration serviceConfiguration =
          AuthorizationServiceConfiguration(
        authorizationEndpoint:
            'https://nemiteks4prod.b2clogin.com/nemiteks4prod.onmicrosoft.com/b2c_1_signin/oauth2/v2.0/authorize',
        tokenEndpoint:
            'https://nemiteks4prod.b2clogin.com/nemiteks4prod.onmicrosoft.com/b2c_1_signin/oauth2/v2.0/token',
      );

      final AuthorizationResponse? authResult = await _appAuth.authorize(
        AuthorizationRequest(
          clientId,
          redirectUri,
          serviceConfiguration: serviceConfiguration,
          scopes: ['openid', 'offline_access', 'profile'],
        ),
      );

      if (authResult != null) {
        final TokenResponse? tokenResult = await _appAuth.token(
          TokenRequest(
            clientId,
            redirectUri,
            authorizationCode: authResult.authorizationCode!,
            serviceConfiguration: serviceConfiguration,
            codeVerifier: authResult.codeVerifier,
            nonce: authResult.nonce,
            scopes: ['openid', 'offline_access', 'profile'],
          ),
        );

        if (tokenResult != null) {
          setState(() {
            _accessToken = tokenResult.accessToken;
          });

          if (tokenResult.idToken != null) {
            try {
              Map<String, dynamic> decodedToken =
                  JwtDecoder.decode(tokenResult.idToken!);
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
                    content: Text(
                        'Innlogging vellykket, men kunne ikke hente brukerinfo')),
              );
            }
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Innlogging feilet: $e')),
      );
    }
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
                      const Text('Innlogget som:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
              onPressed: () => _login(context),
              child: Text(
                  _userEmail != null ? 'Logg inn på nytt' : 'Logg inn med B2C'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PublicationListScreen()),
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
