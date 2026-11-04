import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokale Ablage: Zugangsdaten in den Einstellungen, Daten-Cache und Warteschlange als JSON-Dateien.
class Storage {
  late SharedPreferences _prefs;
  late Directory _dir;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _dir = await getApplicationDocumentsDirectory();
  }

  String get directoryPath => _dir.path;

  String get serverUrl => _prefs.getString('server') ?? '';
  String? get token => _prefs.getString('token');
  String get userName => _prefs.getString('user_name') ?? '';
  int get userId => _prefs.getInt('user_id') ?? 0;

  Future<void> saveServer(String url) => _prefs.setString('server', url);

  Future<void> saveLogin(String token, int userId, String name) async {
    await _prefs.setString('token', token);
    await _prefs.setInt('user_id', userId);
    await _prefs.setString('user_name', name);
  }

  Future<void> clearToken() => _prefs.remove('token');

  File _file(String name) => File('${_dir.path}/$name');

  Future<dynamic> readJson(String name) async {
    try {
      final f = _file(name);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null; // beschädigte Datei: wie "nicht vorhanden" behandeln
    }
  }

  /// Schreibt erst in eine Hilfsdatei, damit ein Absturz die alte Datei nicht zerstört.
  Future<void> writeJson(String name, Object data) async {
    final tmp = _file('$name.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(_file(name).path);
  }

  Future<void> deleteFile(String name) async {
    final f = _file(name);
    if (await f.exists()) await f.delete();
  }
}
