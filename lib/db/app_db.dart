import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'connection/connection.dart';

part 'app_db.g.dart';

const _uuid = Uuid();

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  /// 'income' | 'expense' | 'both'
  TextColumn get kind => text().withDefault(const Constant('expense'))();

  /// 0xFFRRGGBB
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF3B82F6))();

  /// exemplo: 'category', 'food', 'car', 'home', 'health'
  TextColumn get iconKey => text().withDefault(const Constant('category'))();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// base p/ backup/sync (por enquanto não é UNIQUE)
  TextColumn get uuid => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'income' | 'expense'
  TextColumn get type => text()();

  IntColumn get amountCents => integer()();

  /// Categoria “real” (editável). Mantemos category (snapshot) pra fallback.
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();

  /// snapshot do nome no momento do lançamento (fallback)
  TextColumn get category => text()();

  DateTimeColumn get date => dateTime()();

  TextColumn get note => text().withDefault(const Constant(''))();

  TextColumn get uuid => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId => integer().references(Categories, #id)();

  /// formato 'YYYY-MM' ex: '2026-02'
  TextColumn get monthKey => text()();

  IntColumn get limitCents => integer()();

  TextColumn get uuid => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {categoryId, monthKey},
      ];
}

class TaskTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  DateTimeColumn get startDate => dateTime()();

  /// 'daily' | 'weekly'
  TextColumn get recurrence => text().withDefault(const Constant('daily'))();

  /// a cada X dias/semanas
  IntColumn get interval => integer().withDefault(const Constant(1))();

  /// bitmask: Mon=1<<0 ... Sun=1<<6 (usado no weekly)
  IntColumn get weekdaysMask => integer().withDefault(const Constant(0))();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  TextColumn get uuid => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// se veio de recorrência, aponta pro template
  IntColumn get templateId => integer().nullable().references(TaskTemplates, #id)();

  TextColumn get title => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  TextColumn get uuid => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Categories, Transactions, Budgets, TaskTemplates, Tasks])
class AppDb extends _$AppDb {
  AppDb() : super(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedSystemCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(categories);
            await m.createTable(budgets);
            await m.createTable(taskTemplates);

            await m.addColumn(transactions, transactions.categoryId);
            await m.addColumn(transactions, transactions.uuid);
            await m.addColumn(transactions, transactions.createdAt);
            await m.addColumn(transactions, transactions.updatedAt);
            await m.addColumn(transactions, transactions.deleted);

            await m.addColumn(tasks, tasks.templateId);
            await m.addColumn(tasks, tasks.uuid);
            await m.addColumn(tasks, tasks.createdAt);
            await m.addColumn(tasks, tasks.updatedAt);
            await m.addColumn(tasks, tasks.deleted);

            await _seedSystemCategories();
          }
        },
      );

  // -------------------------
  // Bootstrap (chame no provider)
  // -------------------------
  Future<void> bootstrap() async {
    await _seedSystemCategories();
    await _ensureUuids();
  }

  Future<void> _seedSystemCategories() async {
    final any = await (select(categories)..limit(1)).get();
    if (any.isNotEmpty) return;

    Future<void> add(String name, String kind, int color, String iconKey) async {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: name,
          kind: Value(kind),
          colorValue: Value(color),
          iconKey: Value(iconKey),
          uuid: Value(_uuid.v4()),
        ),
      );
    }

    // Expense defaults
    await add('Alimentação', 'expense', 0xFFEF4444, 'food');
    await add('Transporte', 'expense', 0xFFF59E0B, 'car');
    await add('Casa', 'expense', 0xFF10B981, 'home');
    await add('Saúde', 'expense', 0xFF8B5CF6, 'health');
    await add('Lazer', 'expense', 0xFF3B82F6, 'party');
    await add('Outros', 'both', 0xFF64748B, 'category');

    // Income defaults
    await add('Salário', 'income', 0xFF22C55E, 'wallet');
    await add('Extra', 'income', 0xFF06B6D4, 'cash');
  }

  Future<void> _ensureUuids() async {
    // Preenche uuid vazio com v4 (pra backup/sync depois)
    await _fillEmptyUuid(categories, categories.id, categories.uuid);
    await _fillEmptyUuid(transactions, transactions.id, transactions.uuid);
    await _fillEmptyUuid(tasks, tasks.id, tasks.uuid);
    await _fillEmptyUuid(taskTemplates, taskTemplates.id, taskTemplates.uuid);
    await _fillEmptyUuid(budgets, budgets.id, budgets.uuid);
  }

  Future<void> _fillEmptyUuid<T extends Table>(
    TableInfo<T, dynamic> table,
    IntColumn idCol,
    TextColumn uuidCol,
  ) async {
    final rows = await (select(table)..where((t) => uuidCol.equals(''))).get();
    for (final r in rows) {
      final id = (r as dynamic).id as int;
      await (update(table)..where((t) => idCol.equals(id))).write(
        (table as dynamic).createCompanion(true, uuid: Value(_uuid.v4())),
      );
    }
  }

  // -------------------------
  // Categories
  // -------------------------
  Stream<List<Category>> watchCategories({String? kind}) {
    final q = select(categories)..where((c) => c.archived.equals(false));
    if (kind != null) {
      q.where((c) => c.kind.equals(kind) | c.kind.equals('both'));
    }
    q.orderBy([(c) => OrderingTerm(expression: c.name)]);
    return q.watch();
  }

  Future<int> addCategory({
    required String name,
    required String kind,
    required int colorValue,
    required String iconKey,
  }) {
    return into(categories).insert(
      CategoriesCompanion.insert(
        name: name.trim(),
        kind: Value(kind),
        colorValue: Value(colorValue),
        iconKey: Value(iconKey),
        uuid: Value(_uuid.v4()),
      ),
    );
  }

  Future<void> archiveCategory(int id, bool archived) async {
    await (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        archived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // -------------------------
  // Finance
  // -------------------------
  Stream<List<Transaction>> watchTransactionsForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return (select(transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> addTransaction(TransactionsCompanion data) =>
      into(transactions).insert(data);

  Future<void> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  // -------------------------
  // Budgets
  // -------------------------
  static String monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  Stream<List<Budget>> watchBudgetsForMonth(String monthKey) {
    return (select(budgets)..where((b) => b.monthKey.equals(monthKey))).watch();
  }

  Future<void> upsertBudget({
    required int categoryId,
    required String monthKey,
    required int limitCents,
  }) async {
    await into(budgets).insertOnConflictUpdate(
      BudgetsCompanion.insert(
        categoryId: categoryId,
        monthKey: monthKey,
        limitCents: limitCents,
        uuid: Value(_uuid.v4()),
      ),
    );
  }

  /// total gasto (somente expense) por categoria no mês
  Stream<Map<int, int>> watchExpenseTotalsByCategory(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final q = customSelect(
      '''
      SELECT category_id as categoryId, SUM(amount_cents) as totalCents
      FROM transactions
      WHERE type = 'expense' AND date >= ? AND date < ? AND deleted = 0
      GROUP BY category_id
      ''',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {transactions},
    );

    return q.watch().map((rows) {
      final map = <int, int>{};
      for (final r in rows) {
        final id = r.read<int?>('categoryId');
        final total = r.read<int?>('totalCents') ?? 0;
        if (id != null) map[id] = total;
      }
      return map;
    });
  }

  // -------------------------
  // Routine (instances)
  // -------------------------
  Stream<List<Task>> watchTasksForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return (select(tasks)
          ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.done), (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> addTask(TasksCompanion data) => into(tasks).insert(data);

  Future<void> toggleTask(int id, bool done) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          done: Value(done),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  // -------------------------
  // Recurrence (templates -> instances)
  // -------------------------
  Future<int> addTaskTemplate(TaskTemplatesCompanion data) =>
      into(taskTemplates).insert(data);

  Stream<List<TaskTemplate>> watchTemplates() =>
      (select(taskTemplates)..where((t) => t.active.equals(true))).watch();

  Future<void> ensureTasksForDay(DateTime day) async {
    final templates = await (select(taskTemplates)..where((t) => t.active.equals(true))).get();

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (final tpl in templates) {
      if (!_matchesTemplate(tpl, dayStart)) continue;

      final exists = await (select(tasks)
            ..where((t) =>
                t.templateId.equals(tpl.id) &
                t.date.isBiggerOrEqualValue(dayStart) &
                t.date.isSmallerThanValue(dayEnd)))
          .get();

      if (exists.isNotEmpty) continue;

      await into(tasks).insert(
        TasksCompanion.insert(
          title: tpl.title,
          date: dayStart,
          templateId: Value(tpl.id),
          uuid: Value(_uuid.v4()),
        ),
      );
    }
  }

  bool _matchesTemplate(TaskTemplate tpl, DateTime day) {
    final start = DateTime(tpl.startDate.year, tpl.startDate.month, tpl.startDate.day);
    if (day.isBefore(start)) return false;

    final diffDays = day.difference(start).inDays;

    if (tpl.recurrence == 'daily') {
      return diffDays % tpl.interval == 0;
    }

    // weekly
    final weeks = diffDays ~/ 7;
    if (weeks % tpl.interval != 0) return false;

    final weekdayIndex = (day.weekday - 1); // Mon=0..Sun=6
    final mask = 1 << weekdayIndex;
    return (tpl.weekdaysMask & mask) != 0;
  }
}
