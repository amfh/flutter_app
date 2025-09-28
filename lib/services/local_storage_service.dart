import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  // Save image bytes to file
  static Future<void> writeImage(String filename, List<int> bytes) async {
    final file = await _localFile(filename);
    await file.writeAsBytes(bytes);
  }

  // Read image bytes from file
  static Future<File?> readImageFile(String filename) async {
    final file = await _localFile(filename);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
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
