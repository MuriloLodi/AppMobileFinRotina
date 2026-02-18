import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../db/app_db.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/routine_repository.dart';
import '../../finance/data/finance_repository.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(tasksStreamProvider);
    final day = ref.watch(routineDayProvider);

    String fmtDay(DateTime d) => DateFormat("EEE, dd/MM", 'pt_BR').format(d);

    return Scaffold(
      appBar: AppBar(
        title: Text('Rotina • ${fmtDay(day)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(routineDayProvider.notifier).state = day.subtract(
                const Duration(days: 1),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              final now = DateTime.now();
              ref.read(routineDayProvider.notifier).state = DateTime(
                now.year,
                now.month,
                now.day,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(routineDayProvider.notifier).state = day.add(
                const Duration(days: 1),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/finance');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.attach_money),
            label: 'Finanças',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            label: 'Rotina',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/routine/new'),
        child: const Icon(Icons.add),
      ),
      body: asyncList.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'Sem tarefas',
              subtitle: 'Toque no + para criar sua primeira tarefa do dia.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TaskTile(item: list[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final Task item;
  const _TaskTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(item.id),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await ref.read(dbProvider).deleteTask(item.id);
      },
      child: Card(
        child: CheckboxListTile(
          value: item.done,
          title: Text(item.title),
          onChanged: (v) async {
            await ref.read(dbProvider).toggleTask(item.id, v ?? false);
          },
        ),
      ),
    );
  }
}
