import 'package:flutter_test/flutter_test.dart';
import 'package:vogelzucht_app/models/vogel_model.dart';
import 'package:vogelzucht_app/services/api_service.dart';

void main() {
  test('Vogel.fromJson liest Serverdaten', () {
    final v = Vogel.fromJson({
      'id': '5',
      'art_id': 1,
      'name': 'Hans',
      'ringnr': 'A1',
      'ringjahr': 2024,
      'geschlecht': 'm',
      'eigener_bestand': 1,
      '_label': 'Hans',
      '_f': 0.25,
      '_own': true,
    });
    expect(v.id, 5);
    expect(v.geschlecht, 'm');
    expect(v.eigenerBestand, true);
    expect(v.inbreeding, 0.25);
    expect(v.toJson()['ringnr'], 'A1');
    expect(v.subtitle((_) => 'Hellblau'), '♂ · A1/2024 · Hellblau');
  });

  test('Adresse wird normalisiert', () {
    expect(ApiService.normalizeUrl('meine-seite.de/'), 'https://meine-seite.de');
    expect(ApiService.normalizeUrl(' http://x.de//'), 'http://x.de');
    expect(ApiService.normalizeUrl(''), '');
  });
}
