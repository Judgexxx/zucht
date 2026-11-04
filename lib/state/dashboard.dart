import 'app_state.dart' show asInt;

/// Ein laufendes Gelege (mindestens ein Ei offen oder befruchtet).
class ActiveClutch {
  final Map<String, dynamic> clutch;
  final Map<String, dynamic>? pair;
  final int eggs;
  final DateTime? hatch; // frühester voraussichtlicher Schlupf
  final DateTime? start;
  final int day; // Brutwoche in Tagen, ab 1

  const ActiveClutch({required this.clutch, required this.pair, required this.eggs, required this.hatch, required this.start, required this.day});

  /// Schlupf in den nächsten 3 Tagen (oder überfällig).
  bool isHatchSoon(DateTime now) => hatch != null && hatch!.difference(now).inHours <= 72;
}

/// Eine Voliere / ein Käfig mit Belegung und Brutstatus.
class CageInfo {
  final Map<String, dynamic> cage;
  final List<Map<String, dynamic>> birds;
  final List<ActiveClutch> clutches;

  const CageInfo({required this.cage, required this.birds, required this.clutches});

  bool get isFree => birds.isEmpty;
}

/// Berechnet die Kennzahlen und Karten des Dashboards aus den Daten der Webseite.
class Dashboard {
  final List<Map<String, dynamic>> birds;
  final List<Map<String, dynamic>> pairs;
  final List<Map<String, dynamic>> clutches;
  final List<Map<String, dynamic>> eggs;
  final List<Map<String, dynamic>> cages;
  final List<Map<String, dynamic>> species;
  final DateTime now;

  Dashboard({
    required this.birds,
    required this.pairs,
    required this.clutches,
    required this.eggs,
    required this.cages,
    required this.species,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  static const _activeEggStates = ['offen', 'befruchtet'];

  late final List<Map<String, dynamic>> stock =
      birds.where((b) => (b['status'] ?? 'bestand') == 'bestand').toList();

  int get stockCount => stock.length;

  int get chicksThisYear => birds.where((b) {
        final d = DateTime.tryParse((b['schlupfdatum'] ?? '').toString());
        return d != null && d.year == now.year;
      }).length;

  int get activePairs => pairs.where((p) => (p['status'] ?? 'aktiv') == 'aktiv').length;

  int get breedingPairs => activeClutches.map((c) => asInt(c.clutch['paar_id'])).toSet().length;

  int get activeEggs => activeClutches.fold(0, (sum, c) => sum + c.eggs);

  int get hatchSoon => activeClutches.where((c) => c.isHatchSoon(now)).length;

  int get cageCount => cages.length;

  int get freeCages => cages.where((c) => !_hasStockBirds(asInt(c['id']))).length;

  bool _hasStockBirds(int? cageId) => stock.any((b) => asInt(b['kaefig_id']) == cageId);

  int _brutDays(Map<String, dynamic>? pair) {
    final art = asInt(pair?['art_id']);
    for (final s in species) {
      if (asInt(s['id']) == art) return asInt(s['brutdauer']) ?? 18;
    }
    return 18;
  }

  late final List<ActiveClutch> activeClutches = _buildClutches();

  List<ActiveClutch> _buildClutches() {
    final out = <ActiveClutch>[];
    for (final c in clutches) {
      final id = asInt(c['id']);
      final list = eggs.where((e) => asInt(e['brut_id']) == id && _activeEggStates.contains(e['status'])).toList();
      if (list.isEmpty) continue;

      Map<String, dynamic>? pair;
      for (final p in pairs) {
        if (asInt(p['id']) == asInt(c['paar_id'])) pair = p;
      }
      final days = _brutDays(pair);

      DateTime? hatch;
      DateTime? start = DateTime.tryParse((c['legebeginn'] ?? '').toString());
      for (final e in list) {
        final laid = DateTime.tryParse((e['legedatum'] ?? '').toString());
        final planned = DateTime.tryParse((e['schluepfdatum'] ?? '').toString()) ?? (laid == null ? null : laid.add(Duration(days: days)));
        if (planned != null && (hatch == null || planned.isBefore(hatch))) hatch = planned;
        if (laid != null && (start == null || laid.isBefore(start))) start = laid;
      }
      final day = start == null ? 1 : (now.difference(start).inDays + 1).clamp(1, 99).toInt();
      out.add(ActiveClutch(clutch: c, pair: pair, eggs: list.length, hatch: hatch, start: start, day: day));
    }
    return out;
  }

  /// Karten für alle Käfige/Volieren, nach Name sortiert.
  List<CageInfo> get cageInfos {
    final sorted = List<Map<String, dynamic>>.from(cages)
      ..sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));
    return [
      for (final cage in sorted)
        CageInfo(
          cage: cage,
          birds: _birdsIn(asInt(cage['id'])),
          clutches: activeClutches.where((c) => asInt(c.pair?['kaefig_id']) == asInt(cage['id'])).toList(),
        ),
    ];
  }

  List<Map<String, dynamic>> _birdsIn(int? cageId) {
    final list = stock.where((b) => asInt(b['kaefig_id']) == cageId).toList();
    list.sort((a, b) => (a['_label'] ?? '').toString().toLowerCase().compareTo((b['_label'] ?? '').toString().toLowerCase()));
    return list;
  }

  /// Vögel im Bestand, die keinem Käfig zugeordnet sind.
  List<Map<String, dynamic>> get unassigned {
    final ids = cages.map((c) => asInt(c['id'])).toSet();
    return stock.where((b) {
      final k = asInt(b['kaefig_id']);
      return k == null || !ids.contains(k);
    }).toList();
  }
}
