import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../db/app_db.dart';
import '../data/finance_repository.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key});

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String _type = 'expense';
  String _category = 'Alimentação';
  String _note = '';
  DateTime _date = DateTime.now();
  int _amountCents = 0;

  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int _toCents(String input) {
    // aceita "12,34" ou "12.34" ou "12"
    final cleaned = input.trim().replaceAll('.', '').replaceAll(',', '.');
    final value = double.tryParse(cleaned) ?? 0.0;
    return (value * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo lançamento')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'income', label: Text('Entrada')),
                  ButtonSegment(value: 'expense', label: Text('Saída')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor (ex: 12,50)'),
                validator: (v) {
                  final cents = _toCents(v ?? '');
                  if (cents <= 0) return 'Informe um valor válido';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _category,
                items: const [
                  'Alimentação',
                  'Transporte',
                  'Casa',
                  'Lazer',
                  'Saúde',
                  'Trabalho',
                  'Outros',
                ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                decoration: const InputDecoration(labelText: 'Observação (opcional)'),
                onChanged: (v) => _note = v.trim(),
              ),
              const SizedBox(height: 12),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data'),
                subtitle: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: _date,
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 16),

              FilledButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  _amountCents = _toCents(_amountController.text);

                  final db = ref.read(dbProvider);
                  await db.addTransaction(
                    TransactionsCompanion.insert(
                      type: _type,
                      amountCents: _amountCents,
                      category: _category,
                      date: _date,
                      note: _note,
                    ),
                  );

                  if (mounted) context.pop();
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
