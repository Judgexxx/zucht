import 'package:flutter_test/flutter_test.dart';
import 'package:vogelzucht_app/state/dashboard.dart';

void main() {
  final now = DateTime(2026, 5, 10);

  Dashboard build({List<Map<String, dynamic>>? eggs}) => Dashboard(
        now: now,
        birds: [
          {'id': 1, 'status': 'bestand', 'kaefig_id': 1, 'schlupfdatum': '2026-03-01'},
          {'id': 2, 'status': 'bestand', 'kaefig_id': 1},
          {'id': 3, 'status': 'verkauft', 'kaefig_id': 1},
          {'id': 4, 'status': 'bestand', 'kaefig_id': null},
        ],
        pairs: [
          {'id': 1, 'status': 'aktiv', 'kaefig_id': 1, 'art_id': 1},
          {'id': 2, 'status': 'beendet', 'kaefig_id': 2, 'art_id': 1},
        ],
        clutches: [
          {'id': 1, 'paar_id': 1, 'legebeginn': '2026-05-01'},
        ],
        eggs: eggs ??
            [
              {'id': 1, 'brut_id': 1, 'status': 'befruchtet', 'legedatum': '2026-05-01'},
              {'id': 2, 'brut_id': 1, 'status': 'offen', 'legedatum': '2026-05-03'},
              {'id': 3, 'brut_id': 1, 'status': 'unbefruchtet', 'legedatum': '2026-05-02'},
            ],
        cages: [
          {'id': 1, 'name': 'V1', 'typ': 'voliere'},
          {'id': 2, 'name': 'V2', 'typ': 'zuchtbox'},
        ],
        species: [
          {'id': 1, 'brutdauer': 18},
        ],
      );

  test('Kennzahlen', () {
    final d = build();
    expect(d.stockCount, 3);
    expect(d.activePairs, 1);
    expect(d.breedingPairs, 1);
    expect(d.activeEggs, 2);
    expect(d.chicksThisYear, 1);
    expect(d.cageCount, 2);
    expect(d.freeCages, 1);
  });

  test('Gelege: Schlupf und Tag', () {
    final c = build().activeClutches.single;
    expect(c.eggs, 2);
    expect(c.hatch, DateTime(2026, 5, 19));
    expect(c.day, 10);
    expect(c.isHatchSoon(now), false);
    expect(c.isHatchSoon(DateTime(2026, 5, 17)), true);
  });

  test('Voliere mit Belegung und ohne Zuordnung', () {
    final d = build();
    final infos = d.cageInfos;
    expect(infos.first.birds.length, 2);
    expect(infos.first.clutches.length, 1);
    expect(infos.last.isFree, true);
    expect(d.unassigned.length, 1);
  });

  test('Ohne aktive Eier kein Gelege', () {
    final d = build(eggs: [
      {'id': 1, 'brut_id': 1, 'status': 'geschluepft'}
    ]);
    expect(d.activeClutches, isEmpty);
    expect(d.activeEggs, 0);
  });
}
