import 'package:flutter/material.dart';

import '../models/schema_model.dart';
import 'date_input.dart';

/// Eier einer Brut bearbeiten (Nr., Legedatum, Status, Schlupfdatum).
class EggEditor extends StatefulWidget {
  final List<Map<String, dynamic>> eggs;
  final List<OptionDef> statusOptions;
  final bool enabled;
  final VoidCallback onChanged;

  const EggEditor({
    super.key,
    required this.eggs,
    required this.statusOptions,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<EggEditor> createState() => _EggEditorState();
}

class _EggEditorState extends State<EggEditor> {
  void _add() {
    final next = widget.eggs.length + 1;
    setState(() {
      widget.eggs.add({'id': 0, 'nr': next, 'legedatum': null, 'status': 'offen', 'schluepfdatum': null});
    });
    widget.onChanged();
  }

  void _remove(int i) {
    setState(() => widget.eggs.removeAt(i));
    widget.onChanged();
  }

  void _set(int i, String key, dynamic value) {
    setState(() => widget.eggs[i][key] = value);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.statusOptions.isEmpty ? const [OptionDef('offen', 'offen')] : widget.statusOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Eier', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < widget.eggs.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Ei ${widget.eggs[i]['nr'] ?? i + 1}', style: Theme.of(context).textTheme.titleSmall),
                      const Spacer(),
                      if (widget.enabled)
                        IconButton(
                          tooltip: 'Entfernen',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(i),
                        ),
                    ],
                  ),
                  DateInput(
                    label: 'Legedatum',
                    value: widget.eggs[i]['legedatum']?.toString(),
                    enabled: widget.enabled,
                    onChanged: (v) => _set(i, 'legedatum', v),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: options.any((o) => o.value == widget.eggs[i]['status']) ? widget.eggs[i]['status'].toString() : options.first.value,
                        items: [
                          for (final o in options) DropdownMenuItem<String>(value: o.value, child: Text(o.label)),
                        ],
                        onChanged: widget.enabled ? (v) => _set(i, 'status', v ?? 'offen') : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DateInput(
                    label: 'Schlupfdatum',
                    value: widget.eggs[i]['schluepfdatum']?.toString(),
                    enabled: widget.enabled,
                    onChanged: (v) => _set(i, 'schluepfdatum', v),
                  ),
                ],
              ),
            ),
          ),
        if (widget.enabled)
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Ei hinzufügen'),
          ),
      ],
    );
  }
}
