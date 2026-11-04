import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Fehler bei der Kommunikation mit der Ilch-Seite.
class ApiException implements Exception {
  /// HTTP-Status, 0 = keine Verbindung.
  final int status;
  final String code;
  final String message;

  /// Feldfehler (Feldname -> Text), nur bei Status 422.
  final Map<String, String> fieldErrors;

  const ApiException(this.status, this.code, this.message, [this.fieldErrors = const {}]);

  bool get isNetwork => status == 0;
  bool get isAuth => status == 401;
  bool get isValidation => status == 422;

  @override
  String toString() => message;
}

/// Spricht mit dem API-Controller des Moduls (…/index.php/vogelzucht/api/…).
class ApiService {
  String baseUrl;
  String? token;
  final http.Client _client;
  final Duration timeout;

  ApiService({this.baseUrl = '', this.token, http.Client? client, this.timeout = const Duration(seconds: 25)})
      : _client = client ?? http.Client();

  /// "meine-seite.de/" -> "https://meine-seite.de"
  static String normalizeUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri _uri(String action, [Map<String, String>? query]) {
    return Uri.parse('${normalizeUrl(baseUrl)}/index.php/vogelzucht/api/$action').replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    final t = token;
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
      // Manche Server entfernen den Authorization-Header; dann hilft dieser:
      h['X-Auth-Token'] = t;
    }
    return h;
  }

  Future<Map<String, dynamic>> _send(String method, String action,
      {Map<String, dynamic>? body, Map<String, String>? query}) {
    final uri = _uri(action, query);
    return _run(() => method == 'GET'
        ? _client.get(uri, headers: _headers())
        : _client.post(uri, headers: _headers(), body: jsonEncode(body ?? <String, dynamic>{})));
  }

  /// Anfrage mit Datei(en): Der JSON-Teil steckt im Feld "payload", die Fotos folgen als Dateien.
  Future<Map<String, dynamic>> _sendMultipart(String action, Map<String, dynamic> payload, Map<String, String> files) {
    final uri = _uri(action);
    return _run(() async {
      final req = http.MultipartRequest('POST', uri);
      final h = _headers();
      h.remove('Content-Type'); // wird vom Multipart-Request selbst gesetzt
      req.headers.addAll(h);
      req.fields['payload'] = jsonEncode(payload);
      for (final e in files.entries) {
        req.files.add(await http.MultipartFile.fromPath(e.key, e.value));
      }
      final streamed = await _client.send(req);
      return http.Response.fromStream(streamed);
    }, timeout: const Duration(minutes: 2));
  }

  Future<Map<String, dynamic>> _run(Future<http.Response> Function() request, {Duration? timeout}) async {
    http.Response res;
    try {
      res = await request().timeout(timeout ?? this.timeout);
    } on TimeoutException {
      throw const ApiException(0, 'network', 'Der Server antwortet nicht (Zeitüberschreitung).');
    } on SocketException {
      throw const ApiException(0, 'network', 'Keine Verbindung zum Server.');
    } on http.ClientException {
      throw const ApiException(0, 'network', 'Keine Verbindung zum Server.');
    } on HandshakeException {
      throw const ApiException(0, 'network', 'Sichere Verbindung (HTTPS) zum Server fehlgeschlagen.');
    } on FileSystemException {
      throw const ApiException(400, 'file', 'Die ausgewählte Bilddatei konnte nicht gelesen werden.');
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      json = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      throw ApiException(res.statusCode, 'badResponse',
          'Die Antwort des Servers ist kein JSON (Status ${res.statusCode}). Stimmt die Adresse und ist das Modul aktuell?');
    }

    if (res.statusCode >= 400 || json['status'] == 'error') {
      final errors = <String, String>{};
      final labels = json['errorLabels'];
      if (labels is Map) {
        labels.forEach((k, v) => errors[k.toString()] = v.toString());
      }
      throw ApiException(res.statusCode, (json['code'] ?? 'error').toString(),
          (json['message'] ?? 'Fehler (${res.statusCode})').toString(), errors);
    }
    return json;
  }

  /// Prüft, ob unter der Adresse das Modul antwortet.
  Future<void> ping() async {
    await _send('GET', 'ping');
  }

  Future<Map<String, dynamic>> login(String username, String password, String device) {
    return _send('POST', 'login', body: {'username': username, 'password': password, 'device': device});
  }

  Future<void> logout() async {
    await _send('POST', 'logout');
  }

  Future<Map<String, dynamic>> schema() => _send('GET', 'schema');

  Future<Map<String, dynamic>> sync() => _send('GET', 'sync');

  /// Legt an (id = 0) oder aktualisiert. Antwort enthält "id" und "row".
  Future<Map<String, dynamic>> save(String entity, int id, Map<String, dynamic> data, {Map<String, String> files = const {}}) {
    final payload = {'entity': entity, 'id': id, 'data': data};
    if (files.isNotEmpty) return _sendMultipart('save', payload, files);
    return _send('POST', 'save', body: payload);
  }

  Future<void> delete(String entity, int id) async {
    await _send('POST', 'delete', body: {'entity': entity, 'id': id});
  }

  void close() => _client.close();
}
