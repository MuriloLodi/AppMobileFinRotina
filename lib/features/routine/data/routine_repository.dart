import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../db/app_db.dart';
import '../../finance/data/finance_repository.dart';

final routineDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final tasksStreamProvider = StreamProvider.autoDispose((ref) {
  final db = ref.watch(dbProvider);
  final day = ref.watch(routineDayProvider);
  return db.watchTasksForDay(day);
});
