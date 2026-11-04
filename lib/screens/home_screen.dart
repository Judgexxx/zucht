import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../brand.dart';
import '../state/app_state.dart';
import '../state/dashboard.dart';
import '../widgets/side_nav.dart';
import 'form_screen.dart';
import 'sync_screen.dart';

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
String _dm(DateTime t) => '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _search = TextEditingController();
  String _filter = 'alle';
  String _query = '';
  DateTime _now = DateTime.now();
  Timer? _timer;

  static const _filters = <String, String>{
    'alle': 'Alle Volieren',
    'zucht': 'Zuchtvolieren',
    'frei': 'Freiflug',
    'quarantaene': 'Quarantäne',
  };

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _open(String entity, [Map<String, dynamic>? row]) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => FormScreen(entity: entity, row: row)));
  }

  bool _matchesFilter(CageInfo c) {
    final typ = (c.cage['typ'] ?? '').toString();
    switch (_filter) {
      case 'zucht':
        return typ == 'zuchtbox' || typ == 'kaefig' || c.clutches.isNotEmpty;
      case 'frei':
        return typ == 'voliere';
      case 'quarantaene':
        return typ == 'quarantaene';
      default:
        return true;
    }
  }

  bool _matchesQuery(CageInfo c, AppState state) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool has(Object? v) => (v ?? '').toString().toLowerCase().contains(q);
    if (has(c.cage['name']) || has(c.cage['standort'])) return true;
    for (final b in c.birds) {
      if (has(b['ringnr']) || has(b['name']) || has(b['_label']) ||
          has(state.labelOf('mutationen', asInt(b['mutation_id']))) ||
          has(state.labelOf('arten', asInt(b['art_id'])))) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= 900;

    final content = Column(
      children: [
        _statusBar(state, wide),
        Expanded(
          child: RefreshIndicator(
            onRefresh: state.refresh,
            child: _body(state, wide),
          ),
        ),
      ],
    );

    return Scaffold(
      key: _scaffold,
      backgroundColor: Brand.bg,
      drawer: wide ? null : const Drawer(backgroundColor: Brand.panel, child: SideNav(inDrawer: true)),
      body: wide
          ? Row(children: [const SideNav(inDrawer: false), Expanded(child: content)])
          : SafeArea(child: content),
    );
  }

  Widget _statusBar(AppState state, bool wide) {
    final color = state.lastError != null ? Brand.red : (state.syncing ? Brand.amber : Brand.emeraldHi);
    final text = state.syncing ? 'Synchronisiere …' : (state.lastError != null ? 'Offline' : 'Homepage Live-Sync');
    final initial = state.userName.isEmpty ? '?' : state.userName.substring(0, 1).toUpperCase();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(color: Brand.panel, border: Border(bottom: BorderSide(color: Brand.line))),
      child: Row(
        children: [
          if (!wide)
            IconButton(
              tooltip: 'Menü',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffold.currentState?.openDrawer(),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SyncScreen())),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: tint(color, 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tint(color, 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  if (state.pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Text('${state.pendingCount} offen', style: const TextStyle(color: Brand.amber, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(_hm(_now), style: const TextStyle(color: Brand.soft, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Synchronisieren',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.sync, color: Brand.muted),
            onPressed: state.syncing ? null : state.refresh,
          ),
          PopupMenuButton<String>(
            tooltip: 'Profil',
            color: Brand.panelAlt,
            onSelected: (v) {
              if (v == 'logout') confirmLogout(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(enabled: false, child: Text(state.userName)),
              const PopupMenuItem<String>(value: 'logout', child: Text('Abmelden')),
            ],
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: Brand.panelAlt,
                  child: Text(initial, style: const TextStyle(color: Brand.emeraldText, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AppState state, bool wide) {
    if (state.schema == null) {
      return ListView(children: [
        const SizedBox(height: 120),
        Center(
          child: state.syncing
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(state.lastError ?? 'Noch keine Daten. Nach unten ziehen zum Aktualisieren.',
                      textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted)),
                ),
        ),
      ]);
    }

    final d = state.dashboard();
    final infos = d.cageInfos.where((c) => _matchesFilter(c) && _matchesQuery(c, state)).toList();
    final unassigned = d.unassigned.where((b) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return _filter == 'alle';
      return '${b['ringnr']} ${b['name']} ${b['_label']}'.toLowerCase().contains(q);
    }).toList();

    final cols = wide ? (MediaQuery.of(context).size.width >= 1300 ? 3 : 2) : 1;
    final pad = wide ? 28.0 : 14.0;

    return ListView(
      padding: EdgeInsets.all(pad),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Zucht-Zentrale', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Dein Bestand, deine Volieren, deine Gelege.', style: TextStyle(color: Brand.muted, fontSize: 13)),
              ],
            ),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.icon(
                onPressed: () => _open('voegel'),
                icon: const Icon(Icons.add),
                label: const Text('Vogel erfassen'),
              ),
              OutlinedButton.icon(
                onPressed: () => _open('bruten'),
                icon: const Icon(Icons.egg_outlined),
                label: const Text('Gelege eintragen'),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 18),
        _kpis(d, wide),
        const SizedBox(height: 22),
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Ringnummer, Rasse, Farbe oder Voliere suchen …',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in _filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) => setState(() => _filter = e.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (infos.isEmpty && unassigned.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Keine Volieren gefunden.', style: TextStyle(color: Brand.muted))),
          )
        else
          LayoutBuilder(builder: (context, c) {
            final gap = 16.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final info in infos) SizedBox(width: w, child: _cageCard(state, info)),
                if (unassigned.isNotEmpty) SizedBox(width: w, child: _unassignedCard(state, unassigned)),
              ],
            );
          }),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _kpis(Dashboard d, bool wide) {
    final tiles = <Widget>[
      _kpi(Icons.flutter_dash, Brand.emeraldText, 'Gesamtbestand', '${d.stockCount}', 'Vögel im Bestand'),
      _kpi(Icons.favorite, Brand.blue, 'Zuchtpaare', '${d.activePairs}', '${d.breedingPairs} brüten aktuell'),
      _kpi(Icons.egg, Brand.amber, 'Eier / Küken', '${d.activeEggs} / ${d.chicksThisYear}',
          d.hatchSoon > 0 ? '${d.hatchSoon} Schlupf bald' : 'Küken dieses Jahr'),
      _kpi(Icons.home_work, Brand.purple, 'Volieren', '${d.cageCount}', '${d.freeCages} frei'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth >= 900 ? 4 : 2;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
  }

  Widget _kpi(IconData icon, Color color, String label, String value, String sub) {
    return Panel(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tint(color, 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                Text(sub, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.faint, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _typLabel(String typ) {
    switch (typ) {
      case 'voliere':
        return 'Freiflug-Voliere';
      case 'zuchtbox':
        return 'Zuchtbox';
      case 'quarantaene':
        return 'Quarantäne';
      case 'kaefig':
        return 'Käfig';
      default:
        return 'Sonstiges';
    }
  }

  Widget _cageCard(AppState state, CageInfo info) {
    final cage = info.cage;
    final typ = (cage['typ'] ?? '').toString();
    final quarantine = typ == 'quarantaene';
    final name = (cage['name'] ?? '').toString();
    final standort = (cage['standort'] ?? '').toString();
    final badgeColor = quarantine ? Brand.red : (info.clutches.isNotEmpty ? Brand.amber : Brand.emeraldText);

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Tag(name, color: badgeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    standort.isEmpty ? _typLabel(typ) : '${_typLabel(typ)} · $standort',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Brand.faint, fontSize: 12),
                  ),
                ),
                Text('${info.birds.length}', style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600)),
                const Icon(Icons.flutter_dash, size: 16, color: Brand.faint),
              ],
            ),
          ),
          if (info.birds.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('Keine Vögel in dieser Voliere.', style: TextStyle(color: Brand.faint, fontSize: 13)),
            )
          else
            for (final b in info.birds) _birdRow(state, b),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: _statusPanel(info, quarantine)),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.lastSync == null ? 'Noch nicht synchronisiert' : 'Zuletzt synchronisiert ${_hm(state.lastSync!)}',
                    style: const TextStyle(color: Brand.faint, fontSize: 11),
                  ),
                ),
                TextButton(
                  onPressed: () => _open('kaefige', cage),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                  child: const Text('Details →'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _birdRow(AppState state, Map<String, dynamic> b) {
    final sex = (b['geschlecht'] ?? 'u').toString();
    final sexColor = sex == 'm' ? Brand.blue : (sex == 'w' ? Brand.pink : Brand.muted);
    final symbol = sex == 'm' ? '♂' : (sex == 'w' ? '♀' : '?');
    final ring = (b['ringnr'] ?? '').toString();
    final mut = state.labelOf('mutationen', asInt(b['mutation_id']));
    final art = state.labelOf('arten', asInt(b['art_id']));
    final year = DateTime.tryParse((b['schlupfdatum'] ?? '').toString())?.year ?? asInt(b['ringjahr']);
    final name = (b['name'] ?? '').toString();

    return InkWell(
      onTap: () => _open('voegel', b),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint(sexColor, 0.15), shape: BoxShape.circle),
                child: Text(symbol, style: TextStyle(color: sexColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ring.isEmpty ? (name.isEmpty ? '#${b['id']}' : name) : ring,
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text([if (mut.isNotEmpty) mut, if (art.isNotEmpty) art].join(' · '),
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (year != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Brand.panelAlt, borderRadius: BorderRadius.circular(8)),
                  child: Text('$year', style: const TextStyle(color: Brand.soft, fontSize: 11)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPanel(CageInfo info, bool quarantine) {
    Color color;
    IconData icon;
    String title;
    String? sub;

    if (quarantine) {
      color = Brand.red;
      icon = Icons.warning_amber_rounded;
      title = 'Quarantäne';
      sub = 'Keine Zusammenführung bis zur Freigabe';
    } else if (info.clutches.isNotEmpty) {
      final c = info.clutches.first;
      final soon = c.isHatchSoon(_now);
      color = soon ? Brand.emeraldHi : Brand.amberSolid;
      icon = soon ? Icons.celebration : Icons.egg;
      title = 'Gelege aktiv: ${c.eggs} ${c.eggs == 1 ? 'Ei' : 'Eier'}';
      sub = [
        if (c.hatch != null) 'Vorauss. Schlupf: ${_dm(c.hatch!)}',
        'Tag ${c.day}',
      ].join(' · ');
    } else {
      color = Brand.muted;
      icon = Icons.bedtime_outlined;
      title = 'Ruhephase';
      sub = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint(color, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint(color, 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                if (sub != null) Text(sub, style: TextStyle(color: tint(color, 0.85), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unassignedCard(AppState state, List<Map<String, dynamic>> birds) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Tag('Ohne Voliere', color: Brand.muted),
                Spacer(),
              ],
            ),
          ),
          for (final b in birds) _birdRow(state, b),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
