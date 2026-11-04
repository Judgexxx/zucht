import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schema_model.dart';
import '../models/vogel_model.dart';
import '../brand.dart';
import '../state/app_state.dart';
import 'form_screen.dart';

class ListScreen extends StatefulWidget {
  final String entity;

  const ListScreen({super.key, required this.entity});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final TextEditingController _search = TextEditingController();
  int _speciesId = 0; // 0 = alle
  bool _onlyStock = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(AppState state, EntityDef def, Map<String, dynamic> row, String q) {
    if (q.isEmpty) return true;
    if ((row['_label'] ?? '').toString().toLowerCase().contains(q)) return true;
    for (final c in def.list) {
      final f = def.field(c);
      if (f == null) continue;
      if (state.displayValue(f, row[c]).toLowerCase().contains(q)) return true;
    }
    return false;
  }

  /// Dateiname des Fotos eines Datensatzes (erstes Datei-Feld), sonst null.
  String? _photo(EntityDef def, Map<String, dynamic> row) {
    for (final f in def.fields) {
      if (f.type == 'file') {
        final v = (row[f.name] ?? '').toString();
        if (v.isNotEmpty && (asInt(row['id']) ?? 0) > 0) return v;
      }
    }
    return null;
  }

  String _subtitle(AppState state, EntityDef def, Map<String, dynamic> row) {
    if (def.key == 'voegel') {
      final b = Vogel.fromJson(row);
      final parts = <String>[
        b.subtitle((id) => state.labelOf('mutationen', id)),
        state.labelOf('arten', b.artId),
      ];
      if (b.inbreeding > 0) parts.add('Inzucht ${(b.inbreeding * 100).toStringAsFixed(1).replaceAll('.', ',')} %');
      return parts.where((p) => p.isNotEmpty).join(' · ');
    }
    final parts = <String>[];
    for (final c in def.list) {
      final f = def.field(c);
      if (f == null || f.name == 'name') continue;
      final v = state.displayValue(f, row[c]);
      if (v.isNotEmpty) parts.add(v);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final def = state.def(widget.entity);
    if (def == null) {
      return Scaffold(appBar: brandAppBar(title: const Text('Vogelzucht')), body: const Center(child: Text('Keine Daten.')));
    }

    final q = _search.text.trim().toLowerCase();
    final rows = state.rows(widget.entity).where((r) {
      if (_speciesId != 0 && asInt(r['art_id']) != _speciesId) return false;
      if (widget.entity == 'voegel' && _onlyStock && (r['status'] ?? 'bestand') != 'bestand') return false;
      return _matches(state, def, r, q);
    }).toList();
    rows.sort((a, b) => (a['_label'] ?? '').toString().toLowerCase().compareTo((b['_label'] ?? '').toString().toLowerCase()));

    final species = state.rows('arten');

    return Scaffold(
      appBar: brandAppBar(title: Text(def.title)),
      floatingActionButton: def.writable
          ? FloatingActionButton(
              tooltip: 'Neu',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => FormScreen(entity: widget.entity)),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Suchen …',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _search.clear()),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (def.hasSpeciesField && species.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Alle Arten'),
                    selected: _speciesId == 0,
                    onSelected: (_) => setState(() => _speciesId = 0),
                  ),
                  for (final s in species)
                    ChoiceChip(
                      label: Text((s['_label'] ?? '').toString()),
                      selected: _speciesId == asInt(s['id']),
                      onSelected: (_) => setState(() => _speciesId = asInt(s['id']) ?? 0),
                    ),
                ],
              ),
            ),
          if (widget.entity == 'voegel')
            SwitchListTile(
              dense: true,
              title: const Text('Nur Bestand'),
              value: _onlyStock,
              onChanged: (v) => setState(() => _onlyStock = v),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.refresh,
              child: rows.isEmpty
                  ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Keine Einträge.')))])
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        final id = asInt(r['id']) ?? 0;
                        final own = r['_own'] != false;
                        final photo = _photo(def, r);
                        return Material(
                          color: Brand.panel,
                          child: ListTile(
                          leading: photo == null
                              ? null
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    '${state.imageBase}${Uri.encodeComponent(photo)}',
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48, child: Icon(Icons.image_not_supported)),
                                  ),
                                ),
                          title: Text((r['_label'] ?? '').toString()),
                          subtitle: Text(_subtitle(state, def, r)),
                          trailing: state.hasPending(widget.entity, id)
                              ? const Icon(Icons.sync_problem, size: 20)
                              : (own ? null : const Icon(Icons.lock_outline, size: 18)),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(builder: (_) => FormScreen(entity: widget.entity, row: r)),
                          ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
