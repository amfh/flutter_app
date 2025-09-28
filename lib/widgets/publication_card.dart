import 'package:flutter/material.dart';
import '../models/publication.dart';

class PublicationCard extends StatelessWidget {
  final Publication publication;

  const PublicationCard({super.key, required this.publication});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        leading: publication.imageUrl.isNotEmpty
            ? Image.network(
                "https://www.vvsforeningen.no${publication.imageUrl}",
                width: 50,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.book),
              )
            : const Icon(Icons.book),
        title: Text(publication.title),
        subtitle: Text(
          publication.ingress,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
