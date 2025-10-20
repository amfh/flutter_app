import 'dart:convert';
import 'package:flutter/services.dart';
import 'local_storage_service.dart';

class ProductPublicationService {
  static ProductPublicationService? _instance;
  static ProductPublicationService get instance {
    _instance ??= ProductPublicationService._();
    return _instance!;
  }

  ProductPublicationService._();

  Map<String, dynamic>? _cachedMapping;
  static const String _cacheKey = 'product_publications_mapping.json';

  /// Last ned og cache produkt-publikasjon mapping fra assets eller API
  Future<void> loadAndCacheMapping() async {
    try {
      // Først, prøv å lese fra assets
      final String response = await rootBundle
          .loadString('assets/product_publications_mapping.json');
      final Map<String, dynamic> mapping = jsonDecode(response);

      // Cache til lokal lagring for offline bruk
      await LocalStorageService.writeJson(_cacheKey, mapping);
      _cachedMapping = mapping;

      print(
          '📦 Cached product-publication mapping with ${mapping['products']?.length ?? 0} products');
    } catch (e) {
      print('❌ Error loading product-publication mapping: $e');
      // Hvis det feiler, prøv å lese fra cache
      await _loadFromCache();
    }
  }

  /// Last fra lokal cache
  Future<void> _loadFromCache() async {
    try {
      final cachedData = await LocalStorageService.readJson(_cacheKey);
      if (cachedData != null) {
        _cachedMapping = cachedData;
        print('📦 Loaded product-publication mapping from cache');
      }
    } catch (e) {
      print('❌ Error loading from cache: $e');
    }
  }

  /// Hent publikasjoner som en bruker har tilgang til basert på produkter
  Future<List<PublicationInfo>> getPublicationsForProducts(
      List<String> productIds) async {
    // Sørg for at mapping er lastet
    if (_cachedMapping == null) {
      await loadAndCacheMapping();
    }

    if (_cachedMapping == null) {
      return [];
    }

    final Set<PublicationInfo> publications = {};
    final products = _cachedMapping!['products'] as Map<String, dynamic>?;

    if (products == null) {
      return [];
    }

    for (final productId in productIds) {
      final cleanProductId = _extractProductId(productId);
      final product = products[cleanProductId] as Map<String, dynamic>?;

      if (product != null && product['publications'] is List) {
        final productPublications = product['publications'] as List;

        for (final pub in productPublications) {
          if (pub is Map<String, dynamic>) {
            publications.add(PublicationInfo(
              id: pub['id'] ?? '',
              title: pub['title'] ?? 'Ukjent publikasjon',
              description: pub['description'] ?? '',
              productName: product['name'] ?? 'Ukjent produkt',
            ));
          }
        }
      }
    }

    return publications.toList();
  }

  /// Hent produktinformasjon for et gitt produkt-ID
  Future<ProductInfo?> getProductInfo(String productId) async {
    // Sørg for at mapping er lastet
    if (_cachedMapping == null) {
      await loadAndCacheMapping();
    }

    if (_cachedMapping == null) {
      return null;
    }

    final products = _cachedMapping!['products'] as Map<String, dynamic>?;
    if (products == null) {
      return null;
    }

    final cleanProductId = _extractProductId(productId);
    final product = products[cleanProductId] as Map<String, dynamic>?;

    if (product == null) {
      return null;
    }

    final publications = <PublicationInfo>[];
    if (product['publications'] is List) {
      final productPublications = product['publications'] as List;

      for (final pub in productPublications) {
        if (pub is Map<String, dynamic>) {
          publications.add(PublicationInfo(
            id: pub['id'] ?? '',
            title: pub['title'] ?? 'Ukjent publikasjon',
            description: pub['description'] ?? '',
            productName: product['name'] ?? 'Ukjent produkt',
          ));
        }
      }
    }

    return ProductInfo(
      id: cleanProductId,
      name: product['name'] ?? 'Ukjent produkt',
      description: product['description'] ?? '',
      publications: publications,
    );
  }

  /// Hent alle produkter med publikasjoner
  Future<List<ProductInfo>> getAllProducts() async {
    // Sørg for at mapping er lastet
    if (_cachedMapping == null) {
      await loadAndCacheMapping();
    }

    if (_cachedMapping == null) {
      return [];
    }

    final products = _cachedMapping!['products'] as Map<String, dynamic>?;
    if (products == null) {
      return [];
    }

    final result = <ProductInfo>[];

    for (final entry in products.entries) {
      final productId = entry.key;
      final product = entry.value as Map<String, dynamic>;

      final publications = <PublicationInfo>[];
      if (product['publications'] is List) {
        final productPublications = product['publications'] as List;

        for (final pub in productPublications) {
          if (pub is Map<String, dynamic>) {
            publications.add(PublicationInfo(
              id: pub['id'] ?? '',
              title: pub['title'] ?? 'Ukjent publikasjon',
              description: pub['description'] ?? '',
              productName: product['name'] ?? 'Ukjent produkt',
            ));
          }
        }
      }

      result.add(ProductInfo(
        id: productId,
        name: product['name'] ?? 'Ukjent produkt',
        description: product['description'] ?? '',
        publications: publications,
      ));
    }

    return result;
  }

  /// Ekstraher ren produkt-ID fra rå string (fjern JSON formatering)
  String _extractProductId(String rawProductId) {
    // Hvis det er JSON-formatert, ekstraher ID
    if (rawProductId.contains('"Id"')) {
      final idMatch = RegExp(r'"Id":\s*"([^"]+)"').firstMatch(rawProductId);
      if (idMatch != null) {
        return idMatch.group(1)!;
      }
    }

    // Fjern eventuelle anførselstegn og whitespace
    return rawProductId.replaceAll(RegExp(r'["\s]'), '');
  }

  /// Sjekk om en publikasjon er tilgjengelig for gitte produkter
  Future<bool> isPublicationAvailable(
      String publicationId, List<String> productIds) async {
    final publications = await getPublicationsForProducts(productIds);
    return publications.any((pub) => pub.id == publicationId);
  }
}

/// Dataklasse for publikasjonsinformasjon
class PublicationInfo {
  final String id;
  final String title;
  final String description;
  final String productName;

  PublicationInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.productName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicationInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Dataklasse for produktinformasjon
class ProductInfo {
  final String id;
  final String name;
  final String description;
  final List<PublicationInfo> publications;

  ProductInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.publications,
  });
}
