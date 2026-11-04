import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/schema_model.dart';
import '../services/api_service.dart';
import '../services/storage.dart';
import 'dashboard.dart';

/// Eine noch nicht zum Server übertragene Änderung.
class QueueOp {
  final String opId;
  final String type; // save | delete
  final String entity;
  int rowId; // negativ = lokal angelegt, noch ohne Server-ID
  Map<String, dynamic> data;
  Map<String, String> files; // Feldname -> lokaler Pfad eines noch nicht hochgeladenen Fotos
  String? error; // gesetzt, wenn der Server die Änderung abgelehnt hat
  final int created;

  QueueOp({
    required this.opId,
    required this.type,
    required this.entity,
    required this.rowId,
    required this.data,
    this.files = const {},
    this.error,
    required this.created,
  });

  factory QueueOp.fromJson(Map<String, dynamic> j) => QueueOp(
        opId: j['opId'].toString(),
        type: j['type'].toString(),
        entity: j['entity'].toString(),
        rowId: (j['rowId'] as num).toInt(),
        data: Map<String, dynamic>.from(j['data'] as Map),
        files: j['files'] is Map ? Map<String, String>.from((j['files'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))) : <String, String>{},
        error: j['error']?.toString(),
        created: (j['created'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'type': type,
        'entity': entity,
        'rowId': rowId,
        'data': data,
        'files': files,
        'error': error,
        'created': created,
      };
}

class SaveResult {
  final bool ok;
  final bool queued;
  final String message;
  final Map<String, String> fieldErrors;

  const SaveResult(this.ok, this.queued, this.message, [this.fieldErrors = const {}]);
}

int? asInt(dynamic v) {
  if (v == null || v == '') return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool truthy(dynamic v) => v == true || v == 1 || v == '1';

/// Zentrale Zustandsverwaltung: Anmeldung, lokaler Cache, Warteschlange, Synchronisation.
class AppState extends ChangeNotifier {
  final Storage storage = Storage();
  final ApiService api = ApiService();

  bool ready = false;
  bool loggedIn = false;
  bool sessionExpired = false;
  bool syncing = false;
  String userName = '';
  String? lastError;
  DateTime? lastSync;
  String imageBase = '';

  SchemaDef? schema;
  final Map<String, List<Map<String, dynamic>>> _data = {};
  Map<String, dynamic> feldwerte = {};
  final List<QueueOp> queue = [];
  StreamSubscription<dynamic>? _connection;
  int _opCounter = 0;

  // ------------------------------------------------------------ Start

  Future<void> init() async {
    await storage.init();
    api.baseUrl = storage.serverUrl;
    api.token = storage.token;
    userName = storage.userName;
    loggedIn = api.token != null && api.token!.isNotEmpty;

    final cache = await storage.readJson('cache.json');
    if (cache is Map) {
      try {
        _loadCache(Map<String, dynamic>.from(cache));
      } catch (_) {
        _data.clear();
      }
    }
    final q = await storage.readJson('queue.json');
    if (q is List) {
      for (final o in q) {
        try {
          queue.add(QueueOp.fromJson(Map<String, dynamic>.from(o as Map)));
        } catch (_) {}
      }
    }
    for (final op in queue) {
      if (op.error == null) _applyOp(op);
    }

    ready = true;
    notifyListeners();

    _connection = Connectivity().onConnectivityChanged.listen((dynamic r) {
      final offline = r is List ? (r.isEmpty || r.every((x) => x == ConnectivityResult.none)) : r == ConnectivityResult.none;
      if (!offline && loggedIn && pendingCount > 0) refresh();
    });

    if (loggedIn) refresh();
  }

  @override
  void dispose() {
    _connection?.cancel();
    api.close();
    super.dispose();
  }

  // ------------------------------------------------------------ Anmeldung

  /// Gibt null zurück, wenn es geklappt hat, sonst die Fehlermeldung.
  Future<String?> login(String url, String username, String password) async {
    final base = ApiService.normalizeUrl(url);
    if (base.isEmpty) return 'Bitte die Adresse der Webseite eingeben.';
    api.baseUrl = base;
    api.token = null;
    try {
      await api.ping();
      final res = await api.login(username.trim(), password, 'Android-App');
      final newUser = asInt(res['user_id']) ?? 0;
      if (storage.userId != newUser) {
        // Anderer Benutzer: alte Daten dürfen nicht übernommen werden.
        _data.clear();
        queue.clear();
        feldwerte = {};
        await storage.deleteFile('cache.json');
        await storage.deleteFile('queue.json');
      }
      api.token = res['token'].toString();
      await storage.saveServer(base);
      await storage.saveLogin(api.token!, newUser, (res['name'] ?? username).toString());
      userName = (res['name'] ?? username).toString();
      loggedIn = true;
      sessionExpired = false;
      notifyListeners();
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {}
    api.token = null;
    await storage.clearToken();
    loggedIn = false;
    if (queue.isEmpty) {
      _data.clear();
      schema = null;
      await storage.deleteFile('cache.json');
    }
    notifyListeners();
  }

  void _sessionLost() {
    sessionExpired = true;
    loggedIn = false;
    api.token = null;
    storage.clearToken();
    notifyListeners();
  }

  // ------------------------------------------------------------ Lesen

  List<Map<String, dynamic>> rows(String entity) => _data[entity] ?? const [];

  Map<String, dynamic>? row(String entity, int? id) {
    if (id == null) return null;
    for (final r in rows(entity)) {
      if (asInt(r['id']) == id) return r;
    }
    return null;
  }

  String labelOf(String entity, int? id) {
    final r = row(entity, id);
    return r == null ? '' : (r['_label'] ?? '').toString();
  }

  EntityDef? def(String entity) => schema?.entity(entity);

  int get pendingCount => queue.where((o) => o.error == null).length;
  List<QueueOp> get failedOps => queue.where((o) => o.error != null).toList();

  bool hasPending(String entity, int id) => queue.any((o) => o.entity == entity && o.rowId == id);

  Map<int, String> freeFieldValues(int birdId) {
    final raw = feldwerte[birdId.toString()];
    final out = <int, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final id = asInt(k);
        if (id != null) out[id] = v.toString();
      });
    }
    return out;
  }

  /// Kennzahlen und Karten für die Startseite aus den aktuellen Daten.
  Dashboard dashboard() => Dashboard(
        birds: rows('voegel'),
        pairs: rows('paare'),
        clutches: rows('bruten'),
        eggs: rows('eier'),
        cages: rows('kaefige'),
        species: rows('arten'),
      );

  String displayValue(FieldDef f, dynamic v) {
    if (v == null || v == '') return '';
    switch (f.type) {
      case 'ref':
        return labelOf(f.ref ?? '', asInt(v));
      case 'select':
        return f.optionLabel(v.toString());
      case 'bool':
        return truthy(v) ? 'Ja' : 'Nein';
      case 'date':
        final s = v.toString();
        final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
        return m == null ? s : '${m.group(3)}.${m.group(2)}.${m.group(1)}';
      case 'decimal':
        final d = double.tryParse(v.toString());
        return d == null ? v.toString() : d.toStringAsFixed(2).replaceAll('.', ',');
      default:
        return v.toString();
    }
  }

  // ------------------------------------------------------------ Synchronisation

  Future<void> refresh() async {
    if (syncing || !loggedIn) return;
    syncing = true;
    lastError = null;
    notifyListeners();
    try {
      await _pushQueue();
      await _pull();
      lastSync = DateTime.now();
    } on ApiException catch (e) {
      if (e.isAuth) {
        _sessionLost();
        lastError = e.message;
      } else {
        lastError = e.message;
      }
    } catch (e) {
      lastError = 'Unerwarteter Fehler: $e';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _pull() async {
    final s = await api.schema();
    final d = await api.sync();
    schema = SchemaDef.fromJson(s);
    _data.clear();
    final raw = Map<String, dynamic>.from(d['data'] as Map);
    raw.forEach((entity, list) {
      _data[entity] = [for (final r in (list as List)) Map<String, dynamic>.from(r as Map)];
    });
    final fw = d['feldwerte'];
    feldwerte = fw is Map ? Map<String, dynamic>.from(fw) : {};
    imageBase = (d['image_base'] ?? '').toString();
    // Noch nicht übertragene Änderungen bleiben sichtbar.
    for (final op in queue) {
      if (op.error == null) _applyOp(op);
    }
    await _persistCache();
  }

  Future<void> _pushQueue() async {
    for (final op in List<QueueOp>.from(queue)) {
      if (op.error != null) continue;
      try {
        if (op.type == 'save') {
          final res = await api.save(op.entity, op.rowId < 0 ? 0 : op.rowId, op.data, files: op.files);
          final newId = asInt(res['id']) ?? 0;
          if (op.rowId < 0) {
            _removeRow(op.entity, op.rowId);
            _remapQueue(op.entity, op.rowId, newId);
          }
        } else {
          await api.delete(op.entity, op.rowId);
        }
        queue.remove(op);
        for (final path in op.files.values) {
          _deleteLocalFile(path);
        }
      } on ApiException catch (e) {
        if (e.isNetwork || e.isAuth) rethrow;
        op.error = e.fieldErrors.isNotEmpty ? e.fieldErrors.values.join(', ') : e.message;
      }
      await _persistQueue();
    }
  }

  /// Nach dem Anlegen eines Datensatzes: lokale Platzhalter-ID in wartenden Änderungen ersetzen.
  void _remapQueue(String entity, int tempId, int newId) {
    for (final op in queue) {
      final d = def(op.entity);
      if (d == null) continue;
      for (final f in d.fields) {
        if (f.type == 'ref' && f.ref == entity && asInt(op.data[f.name]) == tempId) {
          op.data[f.name] = newId;
        }
      }
    }
  }

  /// Fehlgeschlagene Änderung verwerfen (und lokal zurücknehmen beim nächsten Abgleich).
  Future<void> discard(QueueOp op) async {
    queue.remove(op);
    for (final path in op.files.values) {
      _deleteLocalFile(path);
    }
    if (op.rowId < 0) _removeRow(op.entity, op.rowId);
    await _persistQueue();
    notifyListeners();
    refresh();
  }

  /// Fehlgeschlagene Änderung erneut versuchen.
  Future<void> retry(QueueOp op) async {
    op.error = null;
    await _persistQueue();
    notifyListeners();
    refresh();
  }

  // ------------------------------------------------------------ Schreiben

  Future<SaveResult> save(String entity, int id, Map<String, dynamic> data, {Map<String, String> files = const {}}) async {
    if (pendingCount == 0 && id >= 0) {
      try {
        final res = await api.save(entity, id, data, files: files);
        final row = res['row'];
        if (row is Map) _upsertRow(entity, Map<String, dynamic>.from(row));
        await _persistCache();
        notifyListeners();
        Future<void>.microtask(refresh); // Folgeänderungen (Ringe, Eier …) vom Server holen
        return SaveResult(true, false, (res['message'] ?? 'Gespeichert.').toString());
      } on ApiException catch (e) {
        if (e.isValidation) return SaveResult(false, false, e.message, e.fieldErrors);
        if (e.isAuth) _sessionLost();
        if (!e.isNetwork) return SaveResult(false, false, e.message);
        // keine Verbindung: unten in die Warteschlange
      }
    }
    await _enqueueSave(entity, id, data, await _keepFiles(files));
    return const SaveResult(true, true, 'Offline gespeichert – wird übertragen, sobald wieder Empfang besteht.');
  }

  Future<SaveResult> delete(String entity, int id) async {
    if (id < 0) {
      // Nie übertragen: einfach die wartende Änderung entfernen.
      queue.removeWhere((o) => o.entity == entity && o.rowId == id);
      _removeRow(entity, id);
      await _persistQueue();
      notifyListeners();
      return const SaveResult(true, false, 'Gelöscht.');
    }
    if (pendingCount == 0) {
      try {
        await api.delete(entity, id);
        _removeRow(entity, id);
        await _persistCache();
        notifyListeners();
        Future<void>.microtask(refresh);
        return const SaveResult(true, false, 'Gelöscht.');
      } on ApiException catch (e) {
        if (e.isAuth) _sessionLost();
        if (!e.isNetwork) return SaveResult(false, false, e.message);
      }
    }
    queue.removeWhere((o) => o.entity == entity && o.rowId == id);
    queue.add(QueueOp(opId: _newOpId(), type: 'delete', entity: entity, rowId: id, data: {}, created: DateTime.now().millisecondsSinceEpoch));
    _removeRow(entity, id);
    await _persistQueue();
    notifyListeners();
    return const SaveResult(true, true, 'Offline gelöscht – wird übertragen, sobald wieder Empfang besteht.');
  }

  Future<void> _enqueueSave(String entity, int id, Map<String, dynamic> data, Map<String, String> files) async {
    final rowId = id == 0 ? _nextTempId() : id;
    QueueOp? existing;
    for (final o in queue) {
      if (o.entity == entity && o.rowId == rowId && o.type == 'save') existing = o;
    }
    final op = existing ??
        QueueOp(opId: _newOpId(), type: 'save', entity: entity, rowId: rowId, data: data, created: DateTime.now().millisecondsSinceEpoch);
    op.data = data;
    if (files.isNotEmpty) {
      for (final old in op.files.values) {
        if (!files.containsValue(old)) _deleteLocalFile(old);
      }
      op.files = files;
    }
    op.error = null;
    if (existing == null) queue.add(op);
    _applyOp(op);
    await _persistQueue();
    await _persistCache();
    notifyListeners();
  }

  /// Fotos für die Warteschlange in den App-Ordner kopieren (der Auswahl-Cache kann geleert werden).
  Future<Map<String, String>> _keepFiles(Map<String, String> files) async {
    final out = <String, String>{};
    for (final e in files.entries) {
      try {
        final target = '${storage.directoryPath}/upload_${DateTime.now().microsecondsSinceEpoch}_${e.key}.jpg';
        await File(e.value).copy(target);
        out[e.key] = target;
      } catch (_) {
        // Datei nicht lesbar: ohne Foto weiter, der Server meldet ggf. "Pflichtfeld"
      }
    }
    return out;
  }

  void _deleteLocalFile(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  int _nextTempId() {
    var lowest = 0;
    for (final o in queue) {
      if (o.rowId < lowest) lowest = o.rowId;
    }
    return lowest - 1;
  }

  String _newOpId() => '${DateTime.now().microsecondsSinceEpoch}-${_opCounter++}';

  // ------------------------------------------------------------ lokale Änderungen

  void _applyOp(QueueOp op) {
    final list = _data.putIfAbsent(op.entity, () => <Map<String, dynamic>>[]);
    if (op.type == 'delete') {
      list.removeWhere((r) => asInt(r['id']) == op.rowId);
      return;
    }
    final index = list.indexWhere((r) => asInt(r['id']) == op.rowId);
    final merged = index >= 0 ? Map<String, dynamic>.from(list[index]) : <String, dynamic>{};
    op.data.forEach((k, v) {
      if (k != 'zf' && k != 'egg') merged[k] = v;
    });
    merged['id'] = op.rowId;
    merged['_own'] = true;
    merged['_label'] = _localLabel(merged);
    if (index >= 0) {
      list[index] = merged;
    } else {
      list.add(merged);
    }
  }

  String _localLabel(Map<String, dynamic> r) {
    for (final k in const ['name', 'ringnr', 'titel', 'veranstaltung', 'bezeichnung']) {
      final v = r[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '#${r['id']}';
  }

  void _upsertRow(String entity, Map<String, dynamic> row) {
    final list = _data.putIfAbsent(entity, () => <Map<String, dynamic>>[]);
    final id = asInt(row['id']);
    final i = list.indexWhere((r) => asInt(r['id']) == id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
  }

  void _removeRow(String entity, int id) {
    _data[entity]?.removeWhere((r) => asInt(r['id']) == id);
  }

  // ------------------------------------------------------------ Ablage

  void _loadCache(Map<String, dynamic> c) {
    if (c['schema'] is Map) schema = SchemaDef.fromJson(Map<String, dynamic>.from(c['schema'] as Map));
    if (c['data'] is Map) {
      Map<String, dynamic>.from(c['data'] as Map).forEach((entity, list) {
        _data[entity] = [for (final r in (list as List)) Map<String, dynamic>.from(r as Map)];
      });
    }
    if (c['feldwerte'] is Map) feldwerte = Map<String, dynamic>.from(c['feldwerte'] as Map);
    imageBase = (c['imageBase'] ?? '').toString();
    if (c['lastSync'] != null) lastSync = DateTime.tryParse(c['lastSync'].toString());
  }

  Future<void> _persistCache() async {
    final s = schema;
    if (s == null) return;
    // Nur echte Serverdaten speichern; wartende Änderungen stehen in der Warteschlange.
    final clean = <String, dynamic>{};
    _data.forEach((entity, list) {
      clean[entity] = list.where((r) => (asInt(r['id']) ?? 0) > 0).toList();
    });
    await storage.writeJson('cache.json', {
      'schema': s.toJson(),
      'data': clean,
      'feldwerte': feldwerte,
      'imageBase': imageBase,
      'lastSync': lastSync?.toIso8601String(),
    });
  }

  Future<void> _persistQueue() => storage.writeJson('queue.json', queue.map((o) => o.toJson()).toList());
}
