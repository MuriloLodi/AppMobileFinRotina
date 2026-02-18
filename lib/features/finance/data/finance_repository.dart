import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../db/app_db.dart';

final dbProvider = Provider<AppDb>((ref) => AppDb());

final financeMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final transactionsStreamProvider = StreamProvider.autoDispose((ref) {
  final db = ref.watch(dbProvider);
  final month = ref.watch(financeMonthProvider);
  return db.watchTransactionsForMonth(month);
});
