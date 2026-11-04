import 'package:flutter/material.dart';

/// Datumsfeld: zeigt dd.MM.yyyy, speichert yyyy-MM-dd.
class DateInput extends StatelessWidget {
  final String label;
  final String? value;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  const DateInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  static DateTime? parse(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m == null) return null;
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  static String show(String? s) {
    final d = parse(s);
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  static String format(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> _pick(BuildContext context) async {
    final initial = parse(value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          border: const OutlineInputBorder(),
          suffixIcon: has && enabled
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null))
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(show(value)),
      ),
    );
  }
}
