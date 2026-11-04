import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/schema_model.dart';
import '../brand.dart';
import '../state/app_state.dart';
import '../widgets/date_input.dart';
import '../widgets/egg_editor.dart';

/// Formular für einen Datensatz. Die Felder kommen aus dem Schema des Servers,
/// dadurch gelten in App und Webseite dieselben Felder und Auswahllisten.
class FormScreen extends StatefulWidget {
  final String entity;
  final Map<String, dynamic>? row;

  const FormScreen({super.key, required this.entity, this.row});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  late final EntityDef _def;
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _text = {};
  final Map<int, TextEditingController> _free = {};
  final List<Map<String, dynamic>> _eggs = [];
  final Map<String, String> _picked = {}; // Feldname -> Pfad des neu gewählten Fotos
  Map<String, String> _errors = {};
  bool _saving = false;
  late final bool _readOnly;

  int get _id => asInt(widget.row?['id']) ?? 0;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _def = state.def(widget.entity)!;
    _readOnly = !_def.writable || (widget.row != null && widget.row!['_own'] == false);

    for (final f in _def.fields) {
      if (f.type == 'file') continue;
      dynamic v = widget.row != null ? widget.row![f.name] : f.defaultValue;
      if (f.type == 'bool') v = truthy(v);
      if (f.type == 'ref') v = asInt(v);
      _values[f.name] = v;
      if (const ['text', 'textarea', 'int', 'decimal'].contains(f.type)) {
        var s = v == null ? '' : v.toString();
        if (f.type == 'decimal' && s.isNotEmpty) {
          final d = double.tryParse(s);
          if (d != null) s = d.toString().replaceAll('.', ',');
          if (s.endsWith(',0')) s = s.substring(0, s.length - 2);
        }
        _text[f.name] = TextEditingController(text: s);
      }
    }

    if (widget.entity == 'voegel') {
      final values = _id > 0 ? state.freeFieldValues(_id) : <int, String>{};
      for (final field in state.rows('felder')) {
        final fid = asInt(field['id']) ?? 0;
        _free[fid] = TextEditingController(text: values[fid] ?? '');
      }
    }
    if (widget.entity == 'bruten' && _id > 0) {
      for (final e in state.rows('eier')) {
        if (asInt(e['brut_id']) == _id) {
          _eggs.add({
            'id': asInt(e['id']) ?? 0,
            'nr': e['nr'],
            'legedatum': e['legedatum'],
            'status': e['status'] ?? 'offen',
            'schluepfdatum': e['schluepfdatum'],
          });
        }
      }
      _eggs.sort((a, b) => (asInt(a['nr']) ?? 0).compareTo(asInt(b['nr']) ?? 0));
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    for (final c in _free.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(String field, ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (x != null && mounted) setState(() => _picked[field] = x.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Das Foto konnte nicht geladen werden: $e')));
    }
  }

  // ------------------------------------------------------------ Eingaben einsammeln

  Map<String, dynamic>? _collect() {
    final errors = <String, String>{};
    final data = <String, dynamic>{};
    for (final f in _def.fields) {
      if (f.type == 'file') {
        final has = (widget.row?[f.name] ?? '').toString().isNotEmpty || _picked.containsKey(f.name);
        if (f.required && !has) errors[f.name] = 'Bitte ein Foto auswählen.';
        continue;
      }
      dynamic v;
      switch (f.type) {
        case 'text':
        case 'textarea':
          v = _text[f.name]!.text.trim();
          break;
        case 'int':
          final t = _text[f.name]!.text.trim();
          if (t.isEmpty) {
            v = null;
          } else {
            v = int.tryParse(t);
            if (v == null) errors[f.name] = 'Bitte eine ganze Zahl eingeben.';
          }
          break;
        case 'decimal':
          final t = _text[f.name]!.text.trim().replaceAll(',', '.');
          if (t.isEmpty) {
            v = null;
          } else if (double.tryParse(t) == null) {
            errors[f.name] = 'Bitte eine Zahl eingeben.';
          } else {
            v = t;
          }
          break;
        case 'bool':
          v = truthy(_values[f.name]);
          break;
        default:
          v = _values[f.name];
      }
      if (f.required && (v == null || v == '')) errors[f.name] = 'Pflichtfeld';
      data[f.name] = v;
    }
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return null;
    }

    if (widget.entity == 'voegel' && _free.isNotEmpty) {
      data['zf'] = {for (final e in _free.entries) e.key.toString(): e.value.text.trim()};
    }
    if (widget.entity == 'bruten') {
      data['egg'] = [
        for (final e in _eggs)
          {
            'id': e['id'] ?? 0,
            'nr': e['nr'],
            'legedatum': e['legedatum'] ?? '',
            'status': e['status'] ?? 'offen',
            'schluepfdatum': e['schluepfdatum'] ?? '',
          }
      ];
    }
    return data;
  }

  Future<void> _save() async {
    final data = _collect();
    if (data == null) return;
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _errors = {};
    });
    final res = await state.save(widget.entity, _id, data, files: Map<String, String>.from(_picked));
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.ok) {
      messenger.showSnackBar(SnackBar(content: Text(res.message)));
      Navigator.pop(context);
    } else {
      setState(() => _errors = res.fieldErrors);
      messenger.showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: const Text('Das kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final res = await context.read<AppState>().delete(widget.entity, _id);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(res.message)));
    if (res.ok) Navigator.pop(context);
  }

  // ------------------------------------------------------------ Felder

  String _label(FieldDef f) => f.required ? '${f.label} *' : f.label;

  List<Map<String, dynamic>> _refRows(AppState state, FieldDef f) {
    var rows = List<Map<String, dynamic>>.from(state.rows(f.ref ?? ''));
    if (f.sexFilter != null) {
      rows = rows.where((r) => r['geschlecht'] == f.sexFilter).toList();
    }
    if (f.artFilter) {
      final art = asInt(_values['art_id']);
      if (art != null) rows = rows.where((r) => asInt(r['art_id']) == art).toList();
    }
    if (widget.entity == 'voegel' && f.ref == 'voegel') {
      rows = rows.where((r) => asInt(r['id']) != _id).toList();
    }
    final current = asInt(_values[f.name]);
    if (current != null && !rows.any((r) => asInt(r['id']) == current)) {
      final r = state.row(f.ref ?? '', current);
      if (r != null) rows.add(r);
    }
    rows.sort((a, b) => (a['_label'] ?? '').toString().toLowerCase().compareTo((b['_label'] ?? '').toString().toLowerCase()));
    return rows;
  }

  Widget _field(AppState state, FieldDef f) {
    final err = _errors[f.name];
    final enabled = !_readOnly;
    switch (f.type) {
      case 'text':
      case 'textarea':
        return TextField(
          controller: _text[f.name],
          enabled: enabled,
          minLines: f.type == 'textarea' ? 3 : 1,
          maxLines: f.type == 'textarea' ? 8 : 1,
          keyboardType: f.validate == 'email'
              ? TextInputType.emailAddress
              : (f.type == 'textarea' ? TextInputType.multiline : TextInputType.text),
          decoration: InputDecoration(labelText: _label(f), errorText: err, border: const OutlineInputBorder()),
        );
      case 'int':
        return TextField(
          controller: _text[f.name],
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(labelText: _label(f), errorText: err, border: const OutlineInputBorder()),
        );
      case 'decimal':
        return TextField(
          controller: _text[f.name],
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: _label(f), errorText: err, border: const OutlineInputBorder()),
        );
      case 'date':
        return DateInput(
          label: _label(f),
          value: _values[f.name]?.toString(),
          enabled: enabled,
          errorText: err,
          onChanged: (v) => setState(() => _values[f.name] = v),
        );
      case 'select':
        final current = _values[f.name]?.toString();
        final known = f.options.any((o) => o.value == current);
        return InputDecorator(
          decoration: InputDecoration(labelText: _label(f), errorText: err, border: const OutlineInputBorder()),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: known ? current : (f.required ? null : ''),
              items: [
                if (!f.required) const DropdownMenuItem<String>(value: '', child: Text('—')),
                for (final o in f.options) DropdownMenuItem<String>(value: o.value, child: Text(o.label)),
              ],
              onChanged: enabled ? (v) => setState(() => _values[f.name] = v ?? '') : null,
            ),
          ),
        );
      case 'ref':
        final rows = _refRows(state, f);
        final current = asInt(_values[f.name]) ?? 0;
        final valid = current == 0 || rows.any((r) => asInt(r['id']) == current);
        return InputDecorator(
          decoration: InputDecoration(labelText: _label(f), errorText: err, border: const OutlineInputBorder()),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: valid ? current : 0,
              items: [
                const DropdownMenuItem<int>(value: 0, child: Text('—')),
                for (final r in rows)
                  DropdownMenuItem<int>(value: asInt(r['id']) ?? 0, child: Text((r['_label'] ?? '').toString(), overflow: TextOverflow.ellipsis)),
              ],
              onChanged: enabled
                  ? (v) => setState(() {
                        _values[f.name] = (v == null || v == 0) ? null : v;
                      })
                  : null,
            ),
          ),
        );
      case 'bool':
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: truthy(_values[f.name]),
          onChanged: enabled ? (v) => setState(() => _values[f.name] = v) : null,
        );
      case 'file':
        final name = widget.row?[f.name]?.toString() ?? '';
        final picked = _picked[f.name];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label(f), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            if (picked != null)
              Image.file(File(picked), height: 200, fit: BoxFit.contain)
            else if (name.isNotEmpty)
              Image.network(
                '${state.imageBase}${Uri.encodeComponent(name)}',
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text('Bild konnte nicht geladen werden.'),
              )
            else
              const Text('Noch kein Foto.'),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(err, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (enabled)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickPhoto(f.name, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Aus Galerie'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickPhoto(f.name, ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Kamera'),
                  ),
                ],
              ),
          ],
        );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isNew = widget.row == null;
    final eggDef = state.def('eier');
    final eggStatus = eggDef?.field('status')?.options ?? const <OptionDef>[];
    final inbreeding = asInt(widget.row?['id']) != null && widget.row?['_f'] != null
        ? (double.tryParse(widget.row!['_f'].toString()) ?? 0)
        : 0.0;

    return Scaffold(
      appBar: brandAppBar(
        title: Text(isNew ? '${_def.title}: neu' : (widget.row!['_label'] ?? _def.title).toString()),
        actions: [
          if (!isNew && !_readOnly)
            IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_readOnly)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Dieser Eintrag stammt aus der Basisliste der Webseite und kann nicht geändert werden.'),
              ),
            if (widget.entity == 'voegel' && inbreeding > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Inzuchtkoeffizient: ${(inbreeding * 100).toStringAsFixed(2).replaceAll('.', ',')} %'),
              ),
            for (final f in _def.fields)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(state, f)),
            if (_free.isNotEmpty) ...[
              Text('Eigene Felder', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final field in state.rows('felder'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _free[asInt(field['id']) ?? 0],
                    enabled: !_readOnly,
                    decoration: InputDecoration(labelText: (field['_label'] ?? '').toString(), border: const OutlineInputBorder()),
                  ),
                ),
            ],
            if (widget.entity == 'bruten')
              EggEditor(eggs: _eggs, statusOptions: eggStatus, enabled: !_readOnly, onChanged: () => setState(() {})),
            const SizedBox(height: 16),
            if (!_readOnly)
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Speichern'),
              ),
          ],
        ),
      ),
    );
  }
}
