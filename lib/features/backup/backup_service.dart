import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import '../../db/app_db.dart';

class BackupService {
  static const int backupVersion = 1;

  Future<File> exportJson(AppDb db) async {
    final cats = await db.select(db.categories).get();
    final trans = await db.select(db.transactions).get();
    final buds = await db.select(db.budgets).get();
    final tpls = await db.select(db.taskTemplates).get();
    final tasks = await db.select(db.tasks).get();

    final payload = {
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': cats.map(_catToMap).toList(),
      'transactions': trans.map(_trxToMap).toList(),
      'budgets': buds.map(_budToMap).toList(),
      'taskTemplates': tpls.map(_tplToMap).toList(),
      'tasks': tasks.map(_taskToMap).toList(),
    };

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/finrotina_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }

  Future<File> exportCsvTransactions(AppDb db) async {
    final trans = await (db.select(db.transactions)
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .get();

    final sb = StringBuffer();
    sb.writeln('date;type;category;amount;note');

    for (final t in trans) {
      final date = t.date.toIso8601String();
      final amount = (t.amountCents / 100).toStringAsFixed(2).replaceAll('.', ',');
      final cat = (t.category).replaceAll(';', ' ');
      final note = (t.note).replaceAll(';', ' ');
      sb.writeln('$date;${t.type};$cat;$amount;$note');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/finrotina_transactions_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(sb.toString());
    return file;
  }

  Future<void> restoreFromJsonString(AppDb db, String jsonStr) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Backup inválido (JSON não é objeto)');
    }

    final version = decoded['version'];
    if (version != backupVersion) {
      throw Exception('Versão de backup não suportada: $version');
    }

    final categories = List<Map<String, dynamic>>.from(decoded['categories'] ?? const []);
    final transactions = List<Map<String, dynamic>>.from(decoded['transactions'] ?? const []);
    final budgets = List<Map<String, dynamic>>.from(decoded['budgets'] ?? const []);
    final templates = List<Map<String, dynamic>>.from(decoded['taskTemplates'] ?? const []);
    final tasks = List<Map<String, dynamic>>.from(decoded['tasks'] ?? const []);

    await db.transaction(() async {
      // ordem: primeiro tabelas que dependem de FK
      await db.delete(db.transactions).go();
      await db.delete(db.budgets).go();
      await db.delete(db.tasks).go();
      await db.delete(db.taskTemplates).go();
      await db.delete(db.categories).go();

      // Insere tudo preservando IDs
      await db.batch((b) {
        b.insertAll(db.categories, categories.map(_mapToCategoryCompanion).toList());
        b.insertAll(db.taskTemplates, templates.map(_mapToTemplateCompanion).toList());
        b.insertAll(db.tasks, tasks.map(_mapToTaskCompanion).toList());
        b.insertAll(db.budgets, budgets.map(_mapToBudgetCompanion).toList());
        b.insertAll(db.transactions, transactions.map(_mapToTransactionCompanion).toList());
      });
    });

    // se o backup veio vazio, seed padrão (opcional)
    final anyCat = await (db.select(db.categories)..limit(1)).get();
    if (anyCat.isEmpty) {
      await db.bootstrap();
    }
  }

  // ----------------- Map converters (export) -----------------
  Map<String, dynamic> _catToMap(Category c) => {
        'id': c.id,
        'name': c.name,
        'kind': c.kind,
        'colorValue': c.colorValue,
        'iconKey': c.iconKey,
        'archived': c.archived,
        'uuid': c.uuid,
        'createdAt': c.createdAt.toIso8601String(),
        'updatedAt': c.updatedAt.toIso8601String(),
        'deleted': c.deleted,
      };

  Map<String, dynamic> _trxToMap(Transaction t) => {
        'id': t.id,
        'type': t.type,
        'amountCents': t.amountCents,
        'categoryId': t.categoryId,
        'category': t.category,
        'date': t.date.toIso8601String(),
        'note': t.note,
        'uuid': t.uuid,
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt.toIso8601String(),
        'deleted': t.deleted,
      };

  Map<String, dynamic> _budToMap(Budget b) => {
        'id': b.id,
        'categoryId': b.categoryId,
        'monthKey': b.monthKey,
        'limitCents': b.limitCents,
        'uuid': b.uuid,
        'createdAt': b.createdAt.toIso8601String(),
        'updatedAt': b.updatedAt.toIso8601String(),
        'deleted': b.deleted,
      };

  Map<String, dynamic> _tplToMap(TaskTemplate t) => {
        'id': t.id,
        'title': t.title,
        'startDate': t.startDate.toIso8601String(),
        'recurrence': t.recurrence,
        'interval': t.interval,
        'weekdaysMask': t.weekdaysMask,
        'active': t.active,
        'uuid': t.uuid,
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt.toIso8601String(),
        'deleted': t.deleted,
      };

  Map<String, dynamic> _taskToMap(Task t) => {
        'id': t.id,
        'templateId': t.templateId,
        'title': t.title,
        'date': t.date.toIso8601String(),
        'done': t.done,
        'uuid': t.uuid,
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt.toIso8601String(),
        'deleted': t.deleted,
      };

  // ----------------- Map -> Companion (restore) -----------------
  CategoriesCompanion _mapToCategoryCompanion(Map<String, dynamic> m) {
    return CategoriesCompanion(
      id: Value(m['id'] as int),
      name: Value((m['name'] ?? '').toString()),
      kind: Value((m['kind'] ?? 'expense').toString()),
      colorValue: Value((m['colorValue'] ?? 0xFF3B82F6) as int),
      iconKey: Value((m['iconKey'] ?? 'category').toString()),
      archived: Value((m['archived'] ?? false) as bool),
      uuid: Value((m['uuid'] ?? '').toString()),
      createdAt: Value(DateTime.parse(m['createdAt'] as String)),
      updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
      deleted: Value((m['deleted'] ?? false) as bool),
    );
  }

  TaskTemplatesCompanion _mapToTemplateCompanion(Map<String, dynamic> m) {
    return TaskTemplatesCompanion(
      id: Value(m['id'] as int),
      title: Value((m['title'] ?? '').toString()),
      startDate: Value(DateTime.parse(m['startDate'] as String)),
      recurrence: Value((m['recurrence'] ?? 'daily').toString()),
      interval: Value((m['interval'] ?? 1) as int),
      weekdaysMask: Value((m['weekdaysMask'] ?? 0) as int),
      active: Value((m['active'] ?? true) as bool),
      uuid: Value((m['uuid'] ?? '').toString()),
      createdAt: Value(DateTime.parse(m['createdAt'] as String)),
      updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
      deleted: Value((m['deleted'] ?? false) as bool),
    );
  }

  TasksCompanion _mapToTaskCompanion(Map<String, dynamic> m) {
    final tpl = m['templateId'];
    return TasksCompanion(
      id: Value(m['id'] as int),
      templateId: tpl == null ? const Value.absent() : Value(tpl as int),
      title: Value((m['title'] ?? '').toString()),
      date: Value(DateTime.parse(m['date'] as String)),
      done: Value((m['done'] ?? false) as bool),
      uuid: Value((m['uuid'] ?? '').toString()),
      createdAt: Value(DateTime.parse(m['createdAt'] as String)),
      updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
      deleted: Value((m['deleted'] ?? false) as bool),
    );
  }

  BudgetsCompanion _mapToBudgetCompanion(Map<String, dynamic> m) {
    return BudgetsCompanion(
      id: Value(m['id'] as int),
      categoryId: Value(m['categoryId'] as int),
      monthKey: Value((m['monthKey'] ?? '').toString()),
      limitCents: Value((m['limitCents'] ?? 0) as int),
      uuid: Value((m['uuid'] ?? '').toString()),
      createdAt: Value(DateTime.parse(m['createdAt'] as String)),
      updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
      deleted: Value((m['deleted'] ?? false) as bool),
    );
  }

  TransactionsCompanion _mapToTransactionCompanion(Map<String, dynamic> m) {
    final catId = m['categoryId'];
    return TransactionsCompanion(
      id: Value(m['id'] as int),
      type: Value((m['type'] ?? 'expense').toString()),
      amountCents: Value((m['amountCents'] ?? 0) as int),
      categoryId: catId == null ? const Value.absent() : Value(catId as int),
      category: Value((m['category'] ?? '').toString()),
      date: Value(DateTime.parse(m['date'] as String)),
      note: Value((m['note'] ?? '').toString()),
      uuid: Value((m['uuid'] ?? '').toString()),
      createdAt: Value(DateTime.parse(m['createdAt'] as String)),
      updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
      deleted: Value((m['deleted'] ?? false) as bool),
    );
  }
}
