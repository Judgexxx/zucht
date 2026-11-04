import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../brand.dart';
import '../state/app_state.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    String title(QueueOp op) {
      final def = state.def(op.entity);
      final kind = op.type == 'delete' ? 'Löschen' : (op.rowId < 0 ? 'Neu' : 'Ändern');
      final name = op.type == 'save' ? (op.data['name'] ?? op.data['ringnr'] ?? op.data['titel'] ?? '').toString() : '';
      return '$kind: ${def?.title ?? op.entity}${name.isEmpty ? '' : ' – $name'}';
    }

    return Scaffold(
      appBar: brandAppBar(title: const Text('Synchronisieren')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FilledButton.icon(
            onPressed: state.syncing ? null : state.refresh,
            icon: state.syncing
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            label: const Text('Jetzt synchronisieren'),
          ),
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(state.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          Text('Warten auf Übertragung (${state.pendingCount})', style: Theme.of(context).textTheme.titleMedium),
          if (state.pendingCount == 0) const Padding(padding: EdgeInsets.all(8), child: Text('Alles übertragen.')),
          for (final op in state.queue.where((o) => o.error == null))
            Card(child: ListTile(leading: const Icon(Icons.schedule), title: Text(title(op)))),
          if (state.failedOps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Vom Server abgelehnt (${state.failedOps.length})', style: Theme.of(context).textTheme.titleMedium),
            for (final op in state.failedOps)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.orange),
                  title: Text(title(op)),
                  subtitle: Text(op.error ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(tooltip: 'Erneut versuchen', icon: const Icon(Icons.refresh), onPressed: () => state.retry(op)),
                      IconButton(tooltip: 'Verwerfen', icon: const Icon(Icons.delete_outline), onPressed: () => state.discard(op)),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
