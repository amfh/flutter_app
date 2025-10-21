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
                    Text(
                      'Kompetansebiblioteket inneholder blant annet:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12),
                    _PublicationItem(title: 'Rørhåndboka'),
                    _PublicationItem(title: 'Kuldehåndboka'),
                    _PublicationItem(title: 'Prenøk'),
                    _PublicationItem(title: 'Ventøk'),
                    _PublicationItem(
                        title: 'Vannbaserte oppvarmings- og kjølesystemer'),
                    _PublicationItem(title: 'Varmenormen'),
                    SizedBox(height: 16),
                    Text(
                      'Det vender seg til alle som jobber innen VVS- og kuldefaget. Søk og oppslag går lynraskt, og dine bokmerker følger deg, uansett hvilken plattform du velger.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Med Appen har du tilgang til Kompetansebiblioteket, selv om du ikke er tilkoblet Internett.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Alle kan søke i Kompetansebiblioteket, men tilgang til innholdet krever et abonnement.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Løsningen utgis av Skarland Press AS og er utviklet av Raskweb.',
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
