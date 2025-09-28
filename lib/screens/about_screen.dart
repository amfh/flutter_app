import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Om appen'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Color(0xFF2196F3)),
              SizedBox(height: 24),
              Text(
                'Kompetansebiblioteket',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Denne appen gir deg tilgang til digitale publikasjoner, kapitler og underkapitler fra Kompetansebiblioteket. Du kan laste ned innhold for offline bruk, lagre bokmerker og utforske kunnskap på en moderne og brukervennlig måte.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              Text(
                'Versjon 1.0.0',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
