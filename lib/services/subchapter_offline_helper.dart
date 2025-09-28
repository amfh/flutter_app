import '../models/subchapter_detail.dart';
import 'local_storage_service.dart';

dynamic _findSubChapterJson(dynamic chaptersJson, String subChapterId) {
  for (final chapter in chaptersJson) {
    final subs = chapter['SubChapters'] ?? chapter['subchapters'];
    if (subs != null) {
      for (final sub in subs) {
        if (sub['ID'] == subChapterId) {
          return sub;
        }
      }
    }
  }
  return null;
}

Future<SubChapterDetail?> getOfflineSubChapterDetail(
    String bookId, String subChapterId) async {
  final fullContentFile = 'fullcontent_$bookId.json';
  final fullContent = await LocalStorageService.readJson(fullContentFile);
  if (fullContent == null) return null;
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
  final subJson = _findSubChapterJson(chaptersJson, subChapterId);
  if (subJson == null) return null;
  return SubChapterDetail.fromJson(subJson);
}
