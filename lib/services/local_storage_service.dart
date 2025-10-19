import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  // Save image bytes to file
  static Future<void> writeImage(String filename, List<int> bytes) async {
    print(
        '💾 LocalStorageService.writeImage: Starting write of $filename (${bytes.length} bytes)');
    try {
      final file = await _localFile(filename);
      print('💾 Got file object: ${file.path}');

      // Check if directory exists
      final directory = file.parent;
      print('💾 Directory path: ${directory.path}');
      print('💾 Directory exists: ${await directory.exists()}');

      if (!await directory.exists()) {
        print('💾 Creating directory: ${directory.path}');
        await directory.create(recursive: true);
      }

      await file.writeAsBytes(bytes);
      print('💾 Successfully wrote ${bytes.length} bytes to ${file.path}');

      // Verify immediately after write
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      print('💾 Verification: exists=$exists, size=$size bytes');
    } catch (e) {
      print('💥 LocalStorageService.writeImage ERROR: $e');
      rethrow;
    }
  }

  // Read image bytes from file
  static Future<File?> readImageFile(String filename) async {
    print('📖 LocalStorageService.readImageFile: Looking for $filename');
    try {
      final file = await _localFile(filename);
      print('📖 Full path: ${file.path}');

      final exists = await file.exists();
      print('📖 File exists: $exists');

      if (exists) {
        final size = await file.length();
        print('📖 File size: $size bytes');
        return file;
      } else {
        print('📖 File not found: ${file.path}');

        // List directory contents to see what's actually there
        final directory = file.parent;
        if (await directory.exists()) {
          final contents = await directory.list().toList();
          print('📖 Directory contains ${contents.length} items:');
          for (var item in contents.take(10)) {
            // Limit to first 10 items
            final name = item.path.split(Platform.pathSeparator).last;
            if (item is File) {
              final size = await item.length();
              print('   📄 $name ($size bytes)');
            } else {
              print('   📁 $name (directory)');
            }
          }
        } else {
          print('📖 Directory does not exist: ${directory.path}');
        }
      }
    } catch (e) {
      print('💥 LocalStorageService.readImageFile ERROR: $e');
    }
    return null;
  }

  static Future<String> get _localPath async {
    // FIXED: Use same directory as image saving (getApplicationSupportDirectory)
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  static Future<File> _localFile(String filename) async {
    final path = await _localPath;
    return File('$path/$filename');
  }

  static Future<void> writeJson(String filename, dynamic data) async {
    final file = await _localFile(filename);
    await file.writeAsString(jsonEncode(data));
  }

  static Future<dynamic> readJson(String filename) async {
    try {
      final file = await _localFile(filename);
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      return jsonDecode(contents);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearFile(String filename) async {
    final file = await _localFile(filename);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
