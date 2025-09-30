import 'package:jwt_decoder/jwt_decoder.dart';
import '../main.dart';

class PublicationAccessService {
  // Mapping fra publikasjonstittel til tillatte tilgangs-ID-er
  static const Map<String, List<String>> _publicationAccessMap = {
    'Rørhåndboka 2025 Pluss': [
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'cd1093d0-6af4-4e1f-8ec9-08dc9c1adbcb', // Rørhåndboka Pluss; digital; standard
      '51a82c6f-fd8d-4da7-19ee-08dc8d0eb4cf', // Rørhåndboka Pluss; digital; student/lærling
      'dc61ca55-f674-4130-5774-08dcdc85085c', // Rørhåndboka, digital, medlem RørNorge
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
    ],
    'Prenøk': [
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      '19c24caf-5483-493f-9af5-cb49e22c857e', // Prenøk, digital, standard
      '260d956e-ea33-4234-4eaf-08dc8eef6fba', // Prenøk; digital; student/lærling
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      'bdfca2cb-d146-4eea-5162-08dce84ef423', // Prenøk, digital, standard
    ],
    'Styring og regulering av tekniske anlegg i bygg': [
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'b835c4be-b1ae-4e90-7f9b-08dcae237d18', // Styring og reguleringav tekniske anlegg i bygninger; digital; standard
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      '2ab5164c-a27e-4cef-19f4-08dc8d0eb4cf', // Styring og regulering av tekniske anlegg i bygninger; digital; student/lærling
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
    ],
    'VVS-TV': [], // Ingen bestemt rolle
    'Ventøk': [
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      '76361d2e-efcb-45a3-8ec4-08dc9c1adbcb', // Ventøk; digital; student/lærling
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      'e21d2552-380d-4eba-f79d-08dca735dc70', // Ventøk; digital; standard
    ],
    'Varmenormen (2017)': [
      '7af33f69-34b8-4ffb-19f2-08dc8d0eb4cf', // Varmenormen; digital; student/lærling
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      '5ebae859-307e-4690-c290-08dc9ceea8c0', // Varmenormen; digital; standard
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
    ],
    'Vannbaserte oppvarmings- og kjølesystemer (2014)': [
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      'b0e7ebc7-08f2-4736-19ef-08dc8d0eb4cf', // Vannbaserte oppv. og kjølesystemer; digital; student/lærling
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      'e5a3389d-b38c-4d1f-c28e-08dc9ceea8c0', // Vannbaserte oppv. og kjølesystemer; digital; standard
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
    ],
    'Ventilasjonsteknikk Del I (utgave 2019)': [
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      '40501f5c-0e81-49e8-8ec5-08dc9c1adbcb', // Vent.teknikk del I; digital; standard
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      '4524fd69-4d19-4d99-4eb1-08dc8eef6fba', // Vent.teknikk del I; digital; student/lærling
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
    ],
    'Ventilasjonsteknikk Del II (utgave 2019)': [
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      '11ae8204-2612-430b-4eb2-08dc8eef6fba', // Vent.teknikk del II; digital; student/lærling
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      '2705d592-f418-4889-8ec6-08dc9c1adbcb', // Vent.teknikk del II; digital; standard
    ],
    'VVS-tegning med oppgavesamling': [
      '295cf6f0-c3b5-4c1e-19f3-08dc8d0eb4cf', // VVS-tegning; digital; student/lærling
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      'a8a72113-2537-483a-8ec7-08dc9c1adbcb', // VVS-tegning; digital; standard
    ],
    'Kompendium for Fgass-sertifisering (2019)': [
      'cdb97bef-df9e-4f9f-c28d-08dc9ceea8c0', // Kompendium for Fgass-sertifisering
      '31ce9217-53bc-4cf0-be42-08dd055ab2cc', // Kompendium for F-gass sertifisering KURSTILGANG
    ],
    'Praktisk kuldeteknikk': [
      'ac6d81ae-f7a5-474b-c28f-08dc9ceea8c0', // Praktisk kuldeteknikk; digital; standard
      'ff6c57c2-fe44-45ad-7f9c-08dcae237d18', // Praktisk kuldeteknikk; digital; student/lærling
    ],
    'RHB digitalt tillegg': [
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
    ],
    'Sanitærteknikk - Prosjektering og utførelse av sanitærinstallasjoner i bygg':
        [
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      '2fae520c-3008-4341-4eb4-08dc8eef6fba', // Sanitærteknikk; digital; student/lærling
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      '59b02047-af5d-4d34-8ec8-08dc9c1adbcb', // Sanitærteknikk; digital; standard
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
    ],
    'Stensaas, Leif I. Ventilasjonsteknikk Del I - Grunnlaget og systemer (1998)':
        [
      '86bc530b-1a35-414d-435d-08dcfd7f421b', // Stensaas, Vent.teknikk del I (1998), digital, standard
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      '97f26ff2-781e-488b-4eb5-08dc8eef6fba', // Vent.teknikk del I; Leif Stensaas (1998); digital; student/lærling
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
    ],
    'Tekniske bestemmelser - Standard abonnementsvilkår for vann og avløp': [
      '57a691f2-f9e3-4f31-be2c-08dd055ab2cc', // Tekniske bestemmelser, gratis
      '52fd2349-e508-42b0-8ec2-08dc9c1adbcb', // Tekniske bestemmelser
    ],
    'Kuldehåndboka 2007': [
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      '814d0ba9-9453-480b-4eae-08dc8eef6fba', // Kuldehåndboka; digital; student/lærling
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
    ],
    'Veileder for vannbehandling i lukkede energianlegg':
        [], // Ingen bestemt rolle
    'Klimadata M21': [
      'b6c7099d-c57d-43b8-19f5-08dc8d0eb4cf', // Studentpakke
      '0a18bc8b-24d9-4919-19f0-08dc8d0eb4cf', // Klimadata M21; digital; student/lærling
      '65b75dad-8b35-4225-ccdc-08dcde1412be', // KB Total
      'd65933bc-07b6-45ea-4367-08dcfd7f421b', // Klimadata M21, vedlikeh.kostn., digital, standard
      'b0429ab1-b47c-473f-8ec3-08dc9c1adbcb', // Enbrukerpakke
      'a2dd0c91-04c8-47df-be2b-08dd055ab2cc', // Enbrukerpakke, gratis
    ],
    'Inneklima, FDV og HMS i praksis': [], // Ingen bestemt rolle
  };

  /// Hent brukerens tilgangs-ID-er fra JWT token
  static List<String> getUserAccessIds() {
    try {
      final userSession = UserSession.instance;
      if (userSession.idToken == null) return [];

      final decodedToken = JwtDecoder.decode(userSession.idToken!);
      final extensionProducts = decodedToken['extension_Products'];

      if (extensionProducts == null) return [];

      if (extensionProducts is String) {
        // Hvis det er en kommaseparert streng
        return extensionProducts.split(',').map((e) => e.trim()).toList();
      } else if (extensionProducts is List) {
        // Hvis det allerede er en liste
        return extensionProducts.cast<String>();
      }

      return [];
    } catch (e) {
      print('Error getting user access IDs: $e');
      return [];
    }
  }

  /// Sjekk om brukeren har tilgang til en spesifikk publikasjon
  static bool hasAccessToPublication(String publicationTitle) {
    final userAccessIds = getUserAccessIds();
    final publicationAccessIds = _publicationAccessMap[publicationTitle] ?? [];

    // Hvis publikasjonen ikke har noen tilgangsbegrensninger, gi tilgang
    if (publicationAccessIds.isEmpty) return true;

    // Sjekk om brukeren har minst en av de nødvendige tilgangs-ID-ene
    return userAccessIds
        .any((userAccessId) => publicationAccessIds.contains(userAccessId));
  }

  /// Filtrer en liste med publikasjoner basert på brukerens tilganger
  static List<Map<String, dynamic>> filterPublicationsByAccess(
      List<Map<String, dynamic>> publications) {
    return publications.where((publication) {
      final title = publication['Title'] as String? ?? '';
      return hasAccessToPublication(title);
    }).toList();
  }

  /// Debug metode for å se brukerens tilganger
  static Map<String, dynamic> getDebugInfo() {
    final userAccessIds = getUserAccessIds();
    final accessiblePublications = _publicationAccessMap.entries
        .where((entry) => hasAccessToPublication(entry.key))
        .map((entry) => entry.key)
        .toList();

    return {
      'userAccessIds': userAccessIds,
      'accessiblePublications': accessiblePublications,
      'totalPublications': _publicationAccessMap.keys.length,
    };
  }
}
