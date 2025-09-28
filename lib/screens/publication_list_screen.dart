import 'package:flutter/material.dart';
import 'dart:io';
import '../models/publication.dart';
import '../services/publication_service.dart';
import 'publication_detail_screen.dart';
import '../widgets/main_scaffold.dart';

class PublicationListScreen extends StatefulWidget {
  const PublicationListScreen({super.key});

  @override
  State<PublicationListScreen> createState() => _PublicationListScreenState();
}

class _PublicationListScreenState extends State<PublicationListScreen> {
  final PublicationService _service = PublicationService();
  late Future<List<Publication>> _publications;

  @override
  void initState() {
    super.initState();
    _publications = _service.loadPublications();
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Publikasjoner',
      body: FutureBuilder<List<Publication>>(
        future: _publications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Feil: \\${snapshot.error}"));
          }
          final pubs = snapshot.data ?? [];
          if (pubs.isEmpty) {
            return const Center(child: Text("Ingen publikasjoner funnet"));
          }
          return ListView.builder(
            itemCount: pubs.length,
            itemBuilder: (context, index) {
              final pub = pubs[index];
              return FutureBuilder<bool>(
                future: _service.hasFullContentCache(pub.id),
                builder: (context, snapshot) {
                  final hasCache = snapshot.data == true;
                  return FutureBuilder<File?>(
                    future: _service.getCachedImageFile(pub.id),
                    builder: (context, imgSnapshot) {
                      Widget imageWidget;
                      if (imgSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        imageWidget = const SizedBox(
                            width: 50,
                            height: 50,
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)));
                      } else if (imgSnapshot.hasData &&
                          imgSnapshot.data != null) {
                        imageWidget = Image.file(
                          imgSnapshot.data!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.book_sharp),
                        );
                      } else if (pub.imageUrl.isNotEmpty) {
                        // Download and cache image if not present
                        imageWidget = FutureBuilder<File?>(
                          future: _service.downloadAndCacheImage(
                              pub.imageUrl, pub.id),
                          builder: (context, downloadSnapshot) {
                            if (downloadSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)));
                            } else if (downloadSnapshot.hasData &&
                                downloadSnapshot.data != null) {
                              return Image.file(
                                downloadSnapshot.data!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.book_sharp),
                              );
                            } else {
                              return const Icon(Icons.book_sharp);
                            }
                          },
                        );
                      } else {
                        imageWidget = const Icon(Icons.book);
                      }
                      return ListTile(
                        leading: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            imageWidget,
                            if (hasCache)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Icon(Icons.check_circle,
                                    color: Colors.green, size: 20),
                              ),
                          ],
                        ),
                        title: Text(pub.title),
                        subtitle: Text(
                          pub.ingress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PublicationDetailScreen(publication: pub),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
