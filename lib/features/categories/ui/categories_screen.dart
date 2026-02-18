import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../db/db_provider.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const _colors = <int>[
    0xFFEF4444, 0xFFF59E0B, 0xFF10B981, 0xFF3B82F6, 0xFF8B5CF6, 0xFF64748B,
  ];

  static const _icons = <String, IconData>{
    'category': Icons.category,
    'food': Icons.restaurant,
    'car': Icons.directions_car,
    'home': Icons.home,
    'health': Icons.local_hospital,
    'party': Icons.celebration,
    'wallet': Icons.account_balance_wallet,
    'cash': Icons.payments,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final stream = db.watchCategories(kind: null);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          final list = snapshot.data ?? const [];
          if (list.isEmpty) return const Center(child: Text('Sem categorias'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final c = list[i];
              final icon = _icons[c.iconKey] ?? Icons.category;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(c.colorValue),
                    child: Icon(icon, color: Colors.white),
                  ),
                  title: Text(c.name),
                  subtitle: Text('Tipo: ${c.kind}'),
                  trailing: IconButton(
                    icon: Icon(c.archived ? Icons.undo : Icons.archive_outlined),
                    onPressed: () => db.archiveCategory(c.id, !c.archived),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: list.length,
          );
        },
      ),
    );
  }

  Future<void> _openAdd(BuildContext context, WidgetRef ref) async {
    final db = ref.read(dbProvider);
    String name = '';
    String kind = 'expense';
    int color = _colors.first;
    String iconKey = 'category';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova categoria'),
        content: StatefulBuilder(
          builder: (context, set) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Nome'),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField(
                  value: kind,
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Saída')),
                    DropdownMenuItem(value: 'income', child: Text('Entrada')),
                    DropdownMenuItem(value: 'both', child: Text('Ambos')),
                  ],
                  onChanged: (v) => set(() => kind = v as String),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _colors.map((c) {
                    final selected = c == color;
                    return GestureDetector(
                      onTap: () => set(() => color = c),
                      child: CircleAvatar(
                        backgroundColor: Color(c),
                        child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField(
                  value: iconKey,
                  items: _icons.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Row(children: [Icon(e.value), const SizedBox(width: 8), Text(e.key)]),
                          ))
                      .toList(),
                  onChanged: (v) => set(() => iconKey = v as String),
                  decoration: const InputDecoration(labelText: 'Ícone'),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (name.trim().isEmpty) return;
              await db.addCategory(name: name, kind: kind, colorValue: color, iconKey: iconKey);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
