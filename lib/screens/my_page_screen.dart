import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../main.dart';
import '../services/publication_access_service.dart';

class MyPageScreen extends StatefulWidget {
  final String? idToken;
  final String? userEmail;

  const MyPageScreen({
    super.key,
    this.idToken,
    this.userEmail,
  });

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  Map<String, dynamic>? _decodedToken;
  String? _displayName;
  String? _email;
  List<String>? _products;

  @override
  void initState() {
    super.initState();
    _parseTokenData();
  }

  void _parseTokenData() {
    try {
      // Bruk token fra UserSession hvis tilgjengelig
      final token = UserSession.instance.idToken ?? widget.idToken;
      final email = UserSession.instance.userEmail ?? widget.userEmail;

      if (token != null && token.isNotEmpty) {
        _decodedToken = JwtDecoder.decode(token);

        // Hent standardfelter
        _displayName = _decodedToken?['name'] ?? _decodedToken?['given_name'];
        _email =
            email ?? _decodedToken?['emails']?[0] ?? _decodedToken?['email'];

        // Hent extension_Products
        if (_decodedToken?['extension_Products'] != null) {
          final productsValue = _decodedToken!['extension_Products'];
          if (productsValue is String) {
            // Hvis det er en kommaseparert streng
            _products = productsValue.split(',').map((e) => e.trim()).toList();
          } else if (productsValue is List) {
            // Hvis det allerede er en liste
            _products = productsValue.cast<String>();
          }
        }

        setState(() {});
      }
    } catch (e) {
      print('Error parsing token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Min side'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brukerinformasjon
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 32,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Brukerinformasjon',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_displayName != null) ...[
                      _buildInfoRow('Navn', _displayName!),
                      const SizedBox(height: 8),
                    ],
                    if (_email != null) ...[
                      _buildInfoRow('E-post', _email!),
                      const SizedBox(height: 8),
                    ],
                    if (_displayName == null && _email == null)
                      const Text(
                        'Ingen brukerinformasjon tilgjengelig',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Produkter
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 32,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Mine produkter',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_products != null && _products!.isNotEmpty) ...[
                      for (final product in _products!)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  product,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else
                      const Text(
                        'Ingen produkter tilgjengelig',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logg ut knapp
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showLogoutDialog(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logg ut'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tilgjengelige publikasjoner
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.library_books,
                          size: 32,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Tilgjengelige publikasjoner',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    FutureBuilder<Map<String, dynamic>>(
                      future:
                          Future.value(PublicationAccessService.getDebugInfo()),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final debugInfo = snapshot.data!;
                          final accessiblePublications =
                              debugInfo['accessiblePublications'] as List;
                          final totalPublications =
                              debugInfo['totalPublications'] as int;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Du har tilgang til ${accessiblePublications.length} av $totalPublications publikasjoner',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (accessiblePublications.isNotEmpty) ...[
                                const Text(
                                  'Dine tilgjengelige publikasjoner:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...accessiblePublications
                                    .take(5)
                                    .map(
                                      (pubTitle) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2.0),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.book,
                                              color: Colors.blue,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                pubTitle,
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                if (accessiblePublications.length > 5)
                                  Text(
                                    '... og ${accessiblePublications.length - 5} flere',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ] else
                                const Text(
                                  'Ingen publikasjoner tilgjengelig med dine nåværende tilganger',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          );
                        } else {
                          return const Text('Laster tilgangsinformasjon...');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Debug info (kan fjernes i produksjon)
            if (_decodedToken != null) ...[
              const Text(
                'Debug informasjon:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'JWT Token Claims:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._decodedToken!.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logg ut'),
          content: const Text('Er du sikker på at du vil logge ut?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Lukk dialog
              },
              child: const Text('Avbryt'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Tøm UserSession
                await UserSession.instance.clearSession();

                // Lukk dialog og gå tilbake til hovedskjerm
                Navigator.of(context).pop();
                Navigator.of(context).pop();

                // Restart app eller gå til login-skjerm
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MyApp()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logg ut'),
            ),
          ],
        );
      },
    );
  }
}
