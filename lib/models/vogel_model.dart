/// Ein Vogel des Bestands. Die Feldnamen entsprechen der Tabelle des Moduls.
class Vogel {
  final int id;
  final int artId;
  final String name;
  final String ringnr;
  final int? ringjahr;
  final String geschlecht; // m, w, u
  final int? mutationId;
  final String spalterbig;
  final String schlupfdatum;
  final bool eigenerBestand;
  final String status;
  final String statusDatum;
  final int? kaefigId;
  final int? vaterId;
  final int? mutterId;
  final String herkunft;
  final int? herkunftAdresseId;
  final String zukaufDatum;
  final double? zukaufPreis;
  final int? zuchtbewertung;
  final String notiz;

  // Vom Server berechnet (nur Anzeige):
  final String label;
  final double inbreeding;
  final bool own;

  const Vogel({
    this.id = 0,
    this.artId = 0,
    this.name = '',
    this.ringnr = '',
    this.ringjahr,
    this.geschlecht = 'u',
    this.mutationId,
    this.spalterbig = '',
    this.schlupfdatum = '',
    this.eigenerBestand = true,
    this.status = 'bestand',
    this.statusDatum = '',
    this.kaefigId,
    this.vaterId,
    this.mutterId,
    this.herkunft = 'eigen',
    this.herkunftAdresseId,
    this.zukaufDatum = '',
    this.zukaufPreis,
    this.zuchtbewertung,
    this.notiz = '',
    this.label = '',
    this.inbreeding = 0,
    this.own = true,
  });

  static int? _int(dynamic v) {
    if (v == null || v == '') return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double? _double(dynamic v) {
    if (v == null || v == '') return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  static String _str(dynamic v) => v == null ? '' : v.toString();

  factory Vogel.fromJson(Map<String, dynamic> j) {
    return Vogel(
      id: _int(j['id']) ?? 0,
      artId: _int(j['art_id']) ?? 0,
      name: _str(j['name']),
      ringnr: _str(j['ringnr']),
      ringjahr: _int(j['ringjahr']),
      geschlecht: _str(j['geschlecht']).isEmpty ? 'u' : _str(j['geschlecht']),
      mutationId: _int(j['mutation_id']),
      spalterbig: _str(j['spalterbig']),
      schlupfdatum: _str(j['schlupfdatum']),
      eigenerBestand: j['eigener_bestand'] == true || j['eigener_bestand'] == 1 || j['eigener_bestand'] == '1',
      status: _str(j['status']).isEmpty ? 'bestand' : _str(j['status']),
      statusDatum: _str(j['status_datum']),
      kaefigId: _int(j['kaefig_id']),
      vaterId: _int(j['vater_id']),
      mutterId: _int(j['mutter_id']),
      herkunft: _str(j['herkunft']).isEmpty ? 'eigen' : _str(j['herkunft']),
      herkunftAdresseId: _int(j['herkunft_adresse_id']),
      zukaufDatum: _str(j['zukauf_datum']),
      zukaufPreis: _double(j['zukauf_preis']),
      zuchtbewertung: _int(j['zuchtbewertung']),
      notiz: _str(j['notiz']),
      label: _str(j['_label']),
      inbreeding: _double(j['_f']) ?? 0,
      own: j['_own'] != false,
    );
  }

  /// Felder, die beim Speichern an den Server gehen.
  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'art_id': artId,
        'name': name,
        'ringnr': ringnr,
        'ringjahr': ringjahr,
        'geschlecht': geschlecht,
        'mutation_id': mutationId,
        'spalterbig': spalterbig,
        'schlupfdatum': schlupfdatum,
        'eigener_bestand': eigenerBestand,
        'status': status,
        'status_datum': statusDatum,
        'kaefig_id': kaefigId,
        'vater_id': vaterId,
        'mutter_id': mutterId,
        'herkunft': herkunft,
        'herkunft_adresse_id': herkunftAdresseId,
        'zukauf_datum': zukaufDatum,
        'zukauf_preis': zukaufPreis,
        'zuchtbewertung': zuchtbewertung,
        'notiz': notiz,
      };

  /// Kurzbeschreibung für Listen, z. B. "♂ · A1/2024 · Hellblau".
  String subtitle(String Function(int?) mutationName) {
    final parts = <String>[];
    parts.add(geschlecht == 'm' ? '♂' : (geschlecht == 'w' ? '♀' : '?'));
    if (ringnr.isNotEmpty) {
      parts.add(ringjahr != null ? '$ringnr/$ringjahr' : ringnr);
    }
    final m = mutationName(mutationId);
    if (m.isNotEmpty) parts.add(m);
    if (status != 'bestand') parts.add(status);
    return parts.join(' · ');
  }
}
