import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../db/app_db.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/finance_repository.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  String _fmtMonth(DateTime d) => DateFormat.yMMMM('pt_BR').format(d);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(transactionsStreamProvider);
    final month = ref.watch(financeMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Finanças • ${_fmtMonth(month)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              // simples: troca mês - depois você faz picker bonito
              final prev = DateTime(month.year, month.month - 1, 1);
              ref.read(financeMonthProvider.notifier).state = prev;
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              final now = DateTime.now();
              ref.read(financeMonthProvider.notifier).state = DateTime(now.year, now.month, 1);
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 1) context.go('/routine');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Finanças'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Rotina'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/finance/new'),
        child: const Icon(Icons.add),
      ),
      body: asyncList.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'Sem lançamentos',
              subtitle: 'Toque no + para adicionar sua primeira entrada/saída.',
            );
          }

          final incomeCents = list
              .where((t) => t.type == 'income')
              .fold<int>(0, (sum, t) => sum + t.amountCents);
          final expenseCents = list
              .where((t) => t.type == 'expense')
              .fold<int>(0, (sum, t) => sum + t.amountCents);
          final balanceCents = incomeCents - expenseCents;

          String money(int cents) =>
              NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                  .format(cents / 100.0);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resumo do mês', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _line('Entradas', money(incomeCents)),
                        _line('Saídas', money(expenseCents)),
                        const Divider(),
                        _line('Saldo', money(balanceCents), bold: true),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _TransactionTile(item: list[i]),
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final Transaction item;
  const _TransactionTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = item.type == 'income';

    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
        .format(item.amountCents / 100.0);

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
        await ref.read(dbProvider).deleteTransaction(item.id);
      },
      child: Card(
        child: ListTile(
          leading: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward),
          title: Text(item.category),
          subtitle: Text(
            '${DateFormat('dd/MM').format(item.date)}  •  ${item.note.isEmpty ? '—' : item.note}',
          ),
          trailing: Text(
            (isIncome ? '+ ' : '- ') + money,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
