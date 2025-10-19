import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CacheCleanupService {
  /// Completely clears ALL cached data including malformed references
  static Future<void> clearAllCacheData() async {
    try {
      print('🧹 Starting comprehensive cache cleanup...');

      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/cache');

      if (await cacheDir.exists()) {
        // Get all files in cache directory
        final files = await cacheDir.list().toList();
        print('📁 Found ${files.length} cached files to clear');

        int deletedCount = 0;
        for (final file in files) {
          try {
            if (file is File) {
              await file.delete();
              deletedCount++;
              print('🗑️ Deleted: ${file.path.split('/').last}');
            }
          } catch (e) {
            print('❌ Failed to delete ${file.path}: $e');
          }
        }

        print('✅ Successfully deleted $deletedCount cached files');
      } else {
        print('📁 No cache directory found');
      }

      print('🧹 Comprehensive cache cleanup completed');
    } catch (e) {
      print('❌ Cache cleanup error: $e');
    }
  }

  /// Clear only publication-specific cache files
  static Future<void> clearPublicationCache(String publicationId) async {
    try {
      print('🧹 Clearing cache for publication: $publicationId');

      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/cache');

      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        int deletedCount = 0;

        for (final file in files) {
          if (file is File) {
            final fileName = file.path.split('/').last;
            // Clear files related to this publication
            if (fileName.contains(publicationId)) {
              await file.delete();
              deletedCount++;
              print('🗑️ Deleted publication file: $fileName');
            }
          }
        }

        print('✅ Cleared $deletedCount files for publication $publicationId');
      }
    } catch (e) {
      print('❌ Publication cache cleanup error: $e');
    }
  }
}
