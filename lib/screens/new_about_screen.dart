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
                          'Om Kompetansebiblioteket',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 16),
                    Text(
                      'Kompetansebiblioteket er et digitalt bibliotek som gir tilgang til faglitteratur, pensumbøker og publikasjoner innen VVS, energi- og miljøteknikk. Appen er utviklet for fagfolk og studenter som trenger rask og enkel tilgang til oppdatert faginnhold og nyttige verktøy i arbeidshverdagen.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Faginnhold kan lastes ned for offline bruk, slik at du alltid har tilgang – også uten internettforbindelse. Tilgang til innholdet krever et aktivt abonnement med tilhørende publikasjoner.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Løsningen utgis av Nemitek AS og er utviklet av Raskweb.',
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
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

class _PublicationItem extends StatelessWidget {
  final String title;

  const _PublicationItem({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, left: 16.0),
      child: Row(
        children: [
          Icon(
            Icons.book,
            size: 16,
            color: Colors.blue[600],
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
