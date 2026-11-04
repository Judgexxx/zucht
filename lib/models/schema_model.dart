/// Beschreibung der Datentypen des Moduls (kommt vom Server: api/schema).
class OptionDef {
  final String value;
  final String label;

  const OptionDef(this.value, this.label);

  factory OptionDef.fromJson(Map<String, dynamic> j) =>
      OptionDef((j['value'] ?? '').toString(), (j['label'] ?? '').toString());

  Map<String, dynamic> toJson() => {'value': value, 'label': label};
}

class FieldDef {
  final String name;
  final String label;
  final String type; // text, textarea, int, decimal, date, select, ref, bool, file
  final bool required;
  final String? ref;
  final num? min;
  final num? max;
  final dynamic defaultValue;
  final String? sexFilter;
  final bool artFilter;
  final String? validate;
  final List<OptionDef> options;

  const FieldDef({
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.ref,
    this.min,
    this.max,
    this.defaultValue,
    this.sexFilter,
    this.artFilter = false,
    this.validate,
    this.options = const [],
  });

  factory FieldDef.fromJson(Map<String, dynamic> j) {
    final opts = <OptionDef>[];
    final rawOpts = j['options'];
    if (rawOpts is List) {
      for (final o in rawOpts) {
        opts.add(OptionDef.fromJson(Map<String, dynamic>.from(o as Map)));
      }
    }
    return FieldDef(
      name: (j['name'] ?? '').toString(),
      label: (j['label'] ?? j['name'] ?? '').toString(),
      type: (j['type'] ?? 'text').toString(),
      required: j['required'] == true,
      ref: j['ref']?.toString(),
      min: j['min'] is num ? j['min'] as num : null,
      max: j['max'] is num ? j['max'] as num : null,
      defaultValue: j['default'],
      sexFilter: j['sexfilter']?.toString(),
      artFilter: j['artfilter'] == true,
      validate: j['validate']?.toString(),
      options: opts,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'label': label,
        'type': type,
        'required': required,
        if (ref != null) 'ref': ref,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (defaultValue != null) 'default': defaultValue,
        if (sexFilter != null) 'sexfilter': sexFilter,
        'artfilter': artFilter,
        if (validate != null) 'validate': validate,
        'options': options.map((o) => o.toJson()).toList(),
      };

  String optionLabel(String value) {
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return value;
  }
}

class EntityDef {
  final String key;
  final String title;
  final bool writable;
  final bool species;
  final List<String> list;
  final List<FieldDef> fields;

  const EntityDef({
    required this.key,
    required this.title,
    required this.writable,
    required this.species,
    required this.list,
    required this.fields,
  });

  factory EntityDef.fromJson(String key, Map<String, dynamic> j) {
    final fields = <FieldDef>[];
    for (final f in (j['fields'] as List? ?? const [])) {
      fields.add(FieldDef.fromJson(Map<String, dynamic>.from(f as Map)));
    }
    return EntityDef(
      key: key,
      title: (j['title'] ?? key).toString(),
      writable: j['writable'] == true,
      species: j['species'] == true,
      list: [for (final c in (j['list'] as List? ?? const [])) c.toString()],
      fields: fields,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'writable': writable,
        'species': species,
        'list': list,
        'fields': fields.map((f) => f.toJson()).toList(),
      };

  FieldDef? field(String name) {
    for (final f in fields) {
      if (f.name == name) return f;
    }
    return null;
  }

  bool get hasSpeciesField => field('art_id') != null;
}

class SchemaDef {
  /// Reihenfolge wie vom Server geliefert.
  final Map<String, EntityDef> entities;

  const SchemaDef(this.entities);

  factory SchemaDef.fromJson(Map<String, dynamic> j) {
    final out = <String, EntityDef>{};
    final raw = Map<String, dynamic>.from(j['entities'] as Map);
    raw.forEach((key, value) {
      out[key] = EntityDef.fromJson(key, Map<String, dynamic>.from(value as Map));
    });
    return SchemaDef(out);
  }

  Map<String, dynamic> toJson() => {
        'entities': entities.map((k, v) => MapEntry(k, v.toJson())),
      };

  EntityDef? entity(String key) => entities[key];
}
