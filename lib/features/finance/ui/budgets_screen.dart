import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../db/db_provider.dart';
import '../../../db/app_db.dart';
import 'package:intl/intl.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  int _toCents(String s) {
    final cleaned = s.trim().replaceAll('.', '').replaceAll(',', '.');
    final v = double.tryParse(cleaned) ?? 0;
    return (v * 100).round();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final now = DateTime.now();
    final monthKey = AppDb.monthKey(now);

    return Scaffold(
      appBar: AppBar(title: const Text('Orçamentos')),
      body: StreamBuilder(
        stream: db.watchCategories(kind: 'expense'),
        builder: (context, snapCat) {
          final cats = snapCat.data ?? const [];
          return StreamBuilder(
            stream: db.watchBudgetsForMonth(monthKey),
            builder: (context, snapBud) {
              final buds = snapBud.data ?? const [];
              final budMap = {for (final b in buds) b.categoryId: b};

              return StreamBuilder(
                stream: db.watchExpenseTotalsByCategory(now),
                builder: (context, snapSpent) {
                  final spent = snapSpent.data ?? const <int, int>{};

                  if (cats.isEmpty) return const Center(child: Text('Sem categorias de saída'));

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final c = cats[i];
                      final b = budMap[c.id];
                      final limit = b?.limitCents ?? 0;
                      final used = spent[c.id] ?? 0;

                      final pct = (limit <= 0) ? 0.0 : (used / limit).clamp(0.0, 1.0);
                      final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

                      return Card(
                        child: ListTile(
                          title: Text(c.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              LinearProgressIndicator(value: pct),
                              const SizedBox(height: 6),
                              Text('Gasto: ${money.format(used / 100)} • Orçado: ${money.format(limit / 100)}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final controller = TextEditingController(
                                text: limit > 0 ? (limit / 100).toStringAsFixed(2).replaceAll('.', ',') : '',
                              );

                              await showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text('Orçamento • ${c.name}'),
                                  content: TextField(
                                    controller: controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Valor (ex: 300,00)'),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                    FilledButton(
                                      onPressed: () async {
                                        final cents = _toCents(controller.text);
                                        await db.upsertBudget(categoryId: c.id, monthKey: monthKey, limitCents: cents);
                                        if (context.mounted) Navigator.pop(context);
                                      },
                                      child: const Text('Salvar'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
