import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_model.dart';

class StorageService {
  static const String _keyFolders = 'saved_folders';
  static const String _keyFiles = 'saved_files';

  // Ordner & Dateien lokal auf dem Gerät speichern
  static Future<void> saveData(List<FolderItem> folders, List<DrawingFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    
    final foldersJson = jsonEncode(folders.map((f) => f.toJson()).toList());
    final filesJson = jsonEncode(files.map((f) => f.toJson()).toList());

    await prefs.setString(_keyFolders, foldersJson);
    await prefs.setString(_keyFiles, filesJson);
  }

  // Ordner beim Starten laden
  static Future<List<FolderItem>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyFolders);
    if (data == null) return [];
    
    List<dynamic> list = jsonDecode(data);
    return list.map((item) => FolderItem.fromJson(item)).toList();
  }

  // Dateien beim Starten laden
  static Future<List<DrawingFile>> loadFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyFiles);
    if (data == null) return [];

    List<dynamic> list = jsonDecode(data);
    return list.map((item) => DrawingFile.fromJson(item)).toList();
  }
}