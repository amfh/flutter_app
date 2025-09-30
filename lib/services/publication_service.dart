import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
import '../models/publication.dart';
import '../models/chapter.dart';
import '../models/subchapter.dart';
import '../models/subchapter_detail.dart';
import 'local_storage_service.dart';
import 'publication_access_service.dart';

class PublicationService {
  // Download and cache publication image
  Future<File?> downloadAndCacheImage(
      String imageUrl, String publicationId) async {
    if (imageUrl.isEmpty) return null;
    try {
      final url = Uri.parse("https://kompetansebiblioteket.no$imageUrl");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final filename = 'pubimg_$publicationId.img';
        await LocalStorageService.writeImage(filename, response.bodyBytes);
        return await LocalStorageService.readImageFile(filename);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  // Get cached image file for publication
  Future<File?> getCachedImageFile(String publicationId) async {
    final filename = 'pubimg_$publicationId.img';
    return await LocalStorageService.readImageFile(filename);
  }

  // Sjekk om full content cache finnes for en publikasjon
  Future<bool> hasFullContentCache(String publicationId) async {
    final filename = 'fullcontent_$publicationId.json';
    final data = await LocalStorageService.readJson(filename);
    return data != null;
  }

  // Last ned og cache full content for en publikasjon
  Future<void> downloadAndCacheFullContent(String publicationId) async {
    final url = Uri.parse(
        'https://kompetansebiblioteket.no/SkarlandAppService.asmx/BookFullContent?bookID=$publicationId');
    final response = await http.get(url);
    print('Henter fullcontent fra: $url');
    print('Responskode: ${response.statusCode}');
    print(
        'Respons body start: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
    final trimmed = response.body.trim();
    if (response.statusCode == 200 &&
        (trimmed.startsWith('{') || trimmed.startsWith('['))) {
      final data = jsonDecode(response.body);
      final filename = 'fullcontent_$publicationId.json';
      await LocalStorageService.writeJson(filename, data);
      print('Fullcontent lagret til $filename');
    } else {
      throw Exception(
          'Kunne ikke hente fullstendig publikasjon. Respons: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
    }
  }

  // Last ned og cache alt (publikasjoner, kapitler, subkapitler)
  Future<void> downloadAndCacheAll() async {
    // 1. Last ned publikasjoner
    final pubs = await loadPublicationsFromApi();
    await LocalStorageService.writeJson(
        'publications.json',
        pubs
            .map((p) => {
                  'Id': p.id,
                  'Title': p.title,
                  'Ingress': p.ingress,
                  'Url': p.url,
                  'ImageUrl': p.imageUrl,
                })
            .toList());

    // 2. Last ned alle kapitler for hver publikasjon
    List<Map<String, dynamic>> allChapters = [];
    for (final pub in pubs) {
      final chapters = await fetchChaptersFromApi(pub.id);
      for (final c in chapters) {
        allChapters.add({
          'bookId': pub.id,
          'chapter': {
            'ID': c.id,
            'Title': c.title,
            'Url': c.url,
          }
        });
      }
    }
    await LocalStorageService.writeJson('chapters.json', allChapters);

    // 3. Last ned alle subchapters for hver kapittel
    List<Map<String, dynamic>> allSubChapters = [];
    for (final ch in allChapters) {
      final chapterId = ch['chapter']['ID'] as String;
      final subChapters = await fetchSubChaptersFromApi(chapterId);
      for (final s in subChapters) {
        allSubChapters.add({
          'chapterId': chapterId,
          'subchapter': {
            'ID': s.id,
            'Title': s.title,
            'webUrl': s.webUrl,
            'Number': s.number,
          }
        });
      }
    }
    await LocalStorageService.writeJson('subchapters.json', allSubChapters);
  }

  // Hent publikasjoner fra API (ikke cache)
  Future<List<Publication>> loadPublicationsFromApi() async {
    final url = Uri.parse(
        'https://kompetansebiblioteket.no/SkarlandAppService.asmx/BookList');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Publication.fromJson(json)).toList();
    } else {
      throw Exception('Kunne ikke hente publikasjoner');
    }
  }

  // Hent kapitler fra API (ikke cache)
  Future<List<Chapter>> fetchChaptersFromApi(String bookId) async {
    final url = Uri.parse(
        "https://kompetansebiblioteket.no/SkarlandAppService.asmx/BookChapters?bookID=$bookId");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Chapter.fromJson(json)).toList();
    } else {
      throw Exception("Kunne ikke hente kapitler");
    }
  }

  // Hent subchapters fra API (ikke cache)
  Future<List<SubChapter>> fetchSubChaptersFromApi(String chapterId) async {
    String id = chapterId;
    if (!id.startsWith('{')) id = '{$id';
    if (!id.endsWith('}')) id = '$id}';
    final url = Uri.parse(
        'https://kompetansebiblioteket.no/SkarlandAppService.asmx/BookSubChapterList?chapterID=$id');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SubChapter.fromJson(json)).toList();
    } else {
      throw Exception('Kunne ikke hente underkapitler');
    }
  }

  // Hent detaljer for et subkapittel
  Future<SubChapterDetail> fetchSubChapterDetail(String subchapterId) async {
    String id = subchapterId;
    if (!id.startsWith('{')) id = '{$id';
    if (!id.endsWith('}')) id = '$id}';
    final url = Uri.parse(
        'https://kompetansebiblioteket.no/SkarlandAppService.asmx/BookSubChapter?subchapterID=$id');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return SubChapterDetail.fromJson(data);
    } else {
      throw Exception('Kunne ikke hente subkapittel-detaljer');
    }
  }

  // (Fjernet: fetchSubChapters som brukte API)

  // Demo: last publikasjoner lokalt fra assets
  Future<List<Publication>> loadPublications() async {
    final String response =
        await rootBundle.loadString('assets/publications.json');
    final List<dynamic> data = jsonDecode(response);

    // Filtrer publikasjoner basert på brukerens tilganger
    final filteredData = PublicationAccessService.filterPublicationsByAccess(
        data.cast<Map<String, dynamic>>());

    return filteredData.map((json) => Publication.fromJson(json)).toList();
  }

  // Hent kapitler KUN fra lagret fullcontent-fil
  Future<List<Chapter>> fetchChapters(String bookId) async {
    final fullContentFile = 'fullcontent_$bookId.json';
    final fullContent = await LocalStorageService.readJson(fullContentFile);
    print(
        'Leser fra $fullContentFile, data: ${fullContent != null ? 'OK' : 'null'}');
    if (fullContent == null) {
      throw Exception('Ingen lagret fullcontent-data for denne publikasjonen.');
    }
    List<dynamic> chaptersJson = [];
    if (fullContent is Map<String, dynamic>) {
      if (fullContent['Chapters'] != null) {
        chaptersJson = fullContent['Chapters'];
      } else if (fullContent['chapters'] != null) {
        chaptersJson = fullContent['chapters'];
      }
    } else if (fullContent is List) {
      chaptersJson = fullContent;
    }
    if (chaptersJson.isEmpty) {
      throw Exception('Ingen kapitler funnet i fullcontent-data.');
    }
    return chaptersJson.map((json) => Chapter.fromJson(json)).toList();
  }

  // Hent subchapters KUN fra lagret fullcontent-fil
  Future<List<SubChapter>> fetchSubChapters(
      String chapterId, String bookId) async {
    final fullContentFile = 'fullcontent_$bookId.json';
    final fullContent = await LocalStorageService.readJson(fullContentFile);
    if (fullContent == null) {
      throw Exception('Ingen lagret fullcontent-data for denne publikasjonen.');
    }
    List<dynamic> chaptersJson = [];
    if (fullContent is Map<String, dynamic>) {
      if (fullContent['Chapters'] != null) {
        chaptersJson = fullContent['Chapters'];
      } else if (fullContent['chapters'] != null) {
        chaptersJson = fullContent['chapters'];
      }
    } else if (fullContent is List) {
      chaptersJson = fullContent;
    }
    final chapter = chaptersJson.firstWhere(
      (c) => c['ID'] == chapterId,
      orElse: () => null,
    );
    if (chapter != null) {
      List<dynamic> subChaptersJson = [];
      if (chapter['SubChapters'] != null) {
        subChaptersJson = chapter['SubChapters'];
      } else if (chapter['subchapters'] != null) {
        subChaptersJson = chapter['subchapters'];
      }
      return subChaptersJson.map((json) => SubChapter.fromJson(json)).toList();
    } else {
      throw Exception('Ingen subkapitler funnet for dette kapittelet.');
    }
  }
}
