import 'package:flutter/material.dart';
import '../widgets/new_main_scaffold.dart';

class NewAboutScreen extends StatelessWidget {
  const NewAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NewMainScaffold(
      title: 'Om appen',
      currentRoute: '/about',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.blue,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Kompetansebiblioteket',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Divider(),
                    Text(
                      'Denne appen gir deg tilgang til VVS-publikasjoner offline. '
                      'Du kan laste ned publikasjoner når du er online og lese dem senere uten internettforbindelse.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.help,
                          color: Colors.green,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Slik bruker du appen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Divider(),
                    _FeatureItem(
                      icon: Icons.login,
                      title: 'Logg inn',
                      description:
                          'Logg inn med din Azure AD-konto for å få tilgang til publikasjoner.',
                    ),
                    _FeatureItem(
                      icon: Icons.download,
                      title: 'Last ned publikasjoner',
                      description:
                          'Gå til Min side for å laste ned publikasjoner til offline bruk.',
                    ),
                    _FeatureItem(
                      icon: Icons.library_books,
                      title: 'Les offline',
                      description:
                          'Åpne Publikasjoner for å lese nedlastede publikasjoner.',
                    ),
                    _FeatureItem(
                      icon: Icons.sync,
                      title: 'Hold deg oppdatert',
                      description:
                          'Sjekk Min side regelmessig for oppdateringer av publikasjoner.',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: Colors.orange,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Teknisk informasjon',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Divider(),
                    _InfoRow(label: 'Versjon', value: '2.0.0'),
                    _InfoRow(label: 'Plattform', value: 'Flutter'),
                    _InfoRow(label: 'Pålogging', value: 'Azure AD B2C'),
                    _InfoRow(label: 'Offline støtte', value: 'Ja'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }
}
