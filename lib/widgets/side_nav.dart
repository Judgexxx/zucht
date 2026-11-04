import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../brand.dart';
import '../screens/list_screen.dart';
import '../screens/sync_screen.dart';
import '../state/app_state.dart';

Future<void> confirmLogout(BuildContext context) async {
  final state = context.read<AppState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Abmelden?'),
      content: Text(state.queue.isEmpty
          ? 'Die lokal gespeicherten Daten werden entfernt.'
          : 'Es gibt noch ${state.queue.length} nicht übertragene Änderung(en). Sie bleiben gespeichert und werden nach dem nächsten Anmelden übertragen.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abmelden')),
      ],
    ),
  );
  if (ok == true) await state.logout();
}

/// Seitenleiste: Dauerhaft auf Tablets, als Schublade (Menü-Knopf) auf dem Handy.
class SideNav extends StatelessWidget {
  final bool inDrawer;

  const SideNav({super.key, required this.inDrawer});

  void _go(BuildContext context, Widget Function() page) {
    final navigator = Navigator.of(context);
    if (inDrawer) navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => page()));
  }

  Widget _item(BuildContext context, IconData icon, String label,
      {bool active = false, Widget? badge, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? Brand.emerald : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: active ? Colors.white : Brand.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: active ? Colors.white : Brand.muted,
                      ),
                    ),
                  ),
                  if (badge != null) badge,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _count(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Brand.panelAlt, borderRadius: BorderRadius.circular(20)),
        child: Text('$n', style: const TextStyle(color: Brand.soft, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final schema = state.schema;

    String title(String key, String fallback) => schema?.entity(key)?.title ?? fallback;

    Widget entity(String key, IconData icon, String fallback, {Widget? badge}) {
      if (schema != null && schema.entity(key) == null) return const SizedBox.shrink();
      return _item(
        context,
        icon,
        title(key, fallback),
        badge: badge ?? (schema == null ? null : _count(state.rows(key).length)),
        onTap: () => _go(context, () => ListScreen(entity: key)),
      );
    }

    final dashboard = state.dashboard();
    final initial = state.userName.isEmpty ? '?' : state.userName.substring(0, 1).toUpperCase();
    final syncColor = state.lastError != null ? Brand.red : (state.syncing ? Brand.amber : Brand.emeraldHi);

    return Container(
      width: inDrawer ? null : 260,
      decoration: const BoxDecoration(
        color: Brand.panel,
        border: Border(right: BorderSide(color: Brand.line)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const BrandLogo(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(Brand.appName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('Sync mit Ilch', style: TextStyle(color: Brand.emeraldText, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tint(syncColor, 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tint(syncColor, 0.3)),
              ),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: syncColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.syncing ? 'Synchronisiere …' : (state.lastError != null ? 'Offline / Fehler' : 'Homepage Live-Sync'),
                      style: TextStyle(color: syncColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  InkWell(
                    onTap: state.syncing ? null : state.refresh,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.sync, size: 18, color: syncColor),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                children: [
                  _item(
                    context,
                    Icons.pie_chart,
                    'Dashboard',
                    active: true,
                    onTap: () {
                      if (inDrawer) Navigator.of(context).pop();
                    },
                  ),
                  entity('voegel', Icons.flutter_dash, 'Vogelbestand'),
                  entity('kaefige', Icons.meeting_room, 'Volieren & Käfige'),
                  entity(
                    'bruten',
                    Icons.egg,
                    'Gelege & Zucht',
                    badge: dashboard.activeClutches.isEmpty
                        ? null
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: tint(Brand.amberSolid, 0.2), borderRadius: BorderRadius.circular(20)),
                            child: Text('${dashboard.activeClutches.length} Aktive',
                                style: const TextStyle(color: Brand.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                  ),
                  entity('paare', Icons.biotech, 'Paare'),
                  entity('gesundheit', Icons.medical_services, 'Gesundheit'),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
                    child: Text('WEITERE BEREICHE', style: TextStyle(color: Brand.faint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                  entity('ringe', Icons.radio_button_unchecked, 'Ringe'),
                  entity('gewichte', Icons.monitor_weight, 'Gewichte'),
                  entity('ausstellungen', Icons.emoji_events, 'Ausstellungen'),
                  entity('verkaeufe', Icons.sell, 'Verkauf / Zukauf'),
                  entity('adressen', Icons.contacts, 'Adressen'),
                  entity('kasse', Icons.euro, 'Kasse'),
                  entity('termine', Icons.event, 'Termine'),
                  entity('notizen', Icons.note, 'Notizen'),
                  entity('bilder', Icons.photo_library, 'Bildergalerie'),
                  entity('arten', Icons.category, 'Arten'),
                  entity('mutationen', Icons.palette, 'Mutationen'),
                  entity('felder', Icons.tune, 'Eigene Felder'),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
                    child: Text('SYSTEM', style: TextStyle(color: Brand.faint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                  _item(
                    context,
                    Icons.settings,
                    'Synchronisieren',
                    badge: (state.pendingCount + state.failedOps.length) > 0 ? _count(state.pendingCount + state.failedOps.length) : null,
                    onTap: () => _go(context, () => const SyncScreen()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Brand.panelAlt,
                    child: Text(initial, style: const TextStyle(color: Brand.emeraldText, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(state.userName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const Text('Angemeldet', style: TextStyle(color: Brand.faint, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Abmelden',
                    icon: const Icon(Icons.logout, color: Brand.faint),
                    onPressed: () => confirmLogout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
