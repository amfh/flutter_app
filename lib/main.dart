import 'package:flutter/material.dart';
import 'screens/publication_list_screen.dart';
import 'widgets/main_scaffold.dart';
import 'widgets/subchapter_search_bar.dart';
import 'package:openid_client/openid_client_io.dart';
import 'package:url_launcher/url_launcher.dart';

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
          secondary: const Color(0xFF2196f3),
          background: Colors.white,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: const Color(0xFF2196f3),
          onSurface: const Color(0xFF2196f3),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196f3),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196f3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            elevation: 2,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2196f3)),
          ),
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          titleLarge:
              TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFF2196f3),
          textColor: Colors.black,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// Modell for publikasjon
class Book {
  final String id;
  final String title;
  final String shortTitle;
  final String url;
  final String imageUrl;
  final String ingress;

  Book({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.url,
    required this.imageUrl,
    required this.ingress,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['Id'] ?? '',
      title: json['Title'] ?? '',
      shortTitle: json['ShortTitle'] ?? '',
      url: json['Url'] ?? '',
      imageUrl: json['ImageUrl'] ?? '',
      ingress: json['Ingress'] ?? '',
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _login(BuildContext context) async {
    const String clientId = "49eb6aeb-650f-4da9-967b-bb39d8b7ebd0";
    final String authority =
        "https://nemiteks4prod.b2clogin.com/nemiteks4prod.onmicrosoft.com/tfp/b2c_1_signin/v2.0";
    final String redirectUri =
        (Theme.of(context).platform == TargetPlatform.android ||
                Theme.of(context).platform == TargetPlatform.iOS)
            ? "myapp://auth"
            : "http://localhost";
    final List<String> scopes = [
      "openid",
      "offline_access",
      "profile",
    ];

    try {
      var issuer = await Issuer.discover(Uri.parse(authority));
      var client = Client(issuer, clientId);

      var authenticator = Authenticator(
        client,
        scopes: scopes,
        port: 4000, // only for localhost
        redirectUri: Uri.parse(redirectUri),
        urlLancher: (String url) async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      );

      var c = await authenticator.authorize();
      var token = await c.getTokenResponse();
      // TODO: Lagre token og bruk det i appen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Innlogging vellykket!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Innlogging feilet: $e')),
      );
    }
  }

  void _testLaunchUrl() async {
    final uri = Uri.parse('https://flutter.dev');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kunne ikke åpne nettleser!')),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
              child: SizedBox(
                width: 400,
                child: SubchapterSearchBar(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _login(context),
              child: const Text('Logg inn med B2C'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _testLaunchUrl,
              child: const Text('Test åpne nettside'),
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
