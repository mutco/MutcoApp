import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scan_record.dart';

class LocalRepository {
  static const _key = 'mutco_records_v1';
  final SharedPreferences prefs;
  LocalRepository(this.prefs);

  List<ScanRecord> get records {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => ScanRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> save(ScanRecord record) async {
    final all = records..removeWhere((e) => e.id == record.id);
    all.insert(0, record);
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> delete(ScanRecord record) async {
    final all = records..removeWhere((e) => e.id == record.id);
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
    final file = File(record.imagePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> clear() async {
    for (final record in records) {
      final file = File(record.imagePath);
      if (await file.exists()) await file.delete();
    }
    await prefs.remove(_key);
  }

  Future<String> persistImage(String source, String id) async {
    final directory = Directory('${(await getApplicationDocumentsDirectory()).path}/scans');
    await directory.create(recursive: true);
    final path = '${directory.path}/$id.jpg';
    await File(source).copy(path);
    return path;
  }
}
