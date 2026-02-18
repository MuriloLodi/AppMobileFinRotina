import 'package:drift/drift.dart';
import 'connection/connection.dart';

part 'app_db.g.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // 'income' | 'expense'
  IntColumn get amountCents => integer()(); // guardar em centavos
  TextColumn get category => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Transactions, Tasks])
class AppDb extends _$AppDb {
  AppDb() : super(openConnection());

  @override
  int get schemaVersion => 1;

  // Finance
  Future<int> addTransaction(TransactionsCompanion data) =>
      into(transactions).insert(data);

  Stream<List<Transaction>> watchTransactionsForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return (select(transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  // Routine
  Future<int> addTask(TasksCompanion data) => into(tasks).insert(data);

  Stream<List<Task>> watchTasksForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(tasks)
          ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.done), (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> toggleTask(int id, bool done) =>
      (update(tasks)..where((t) => t.id.equals(id)))
          .write(TasksCompanion(done: Value(done)));

  Future<void> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();
}
