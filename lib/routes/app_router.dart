import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/finance/ui/finance_screen.dart';
import '../features/finance/ui/transaction_form_screen.dart';
import '../features/routine/ui/routine_screen.dart';
import '../features/routine/ui/task_form_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/finance',
    routes: [
      GoRoute(
        path: '/finance',
        pageBuilder: (context, state) => const MaterialPage(child: FinanceScreen()),
        routes: [
          GoRoute(
            path: 'new',
            pageBuilder: (context, state) => const MaterialPage(child: TransactionFormScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/routine',
        pageBuilder: (context, state) => const MaterialPage(child: RoutineScreen()),
        routes: [
          GoRoute(
            path: 'new',
            pageBuilder: (context, state) => const MaterialPage(child: TaskFormScreen()),
          ),
        ],
      ),
    ],
  );
});
