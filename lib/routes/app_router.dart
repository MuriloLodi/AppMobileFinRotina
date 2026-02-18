import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/finance/ui/finance_screen.dart';
import '../features/finance/ui/transaction_form_screen.dart';
import '../features/routine/ui/routine_screen.dart';
import '../features/routine/ui/task_form_screen.dart';

import '../features/settings/ui/settings_screen.dart';
import '../features/categories/ui/categories_screen.dart';
import '../features/finance/ui/budgets_screen.dart';
import '../features/backup/ui/backup_screen.dart';
import '../features/security/ui/lock_gate_screen.dart';
import '../features/security/ui/lock_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (_, __) => const MaterialPage(child: LockGateScreen()),
      ),
      GoRoute(
        path: '/lock',
        pageBuilder: (_, __) => const MaterialPage(child: LockScreen()),
      ),
      GoRoute(
        path: '/finance',
        pageBuilder: (_, __) => const MaterialPage(child: FinanceScreen()),
        routes: [
          GoRoute(
            path: 'new',
            pageBuilder: (_, __) => const MaterialPage(child: TransactionFormScreen()),
          ),
          GoRoute(
            path: 'budgets',
            pageBuilder: (_, __) => const MaterialPage(child: BudgetsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/routine',
        pageBuilder: (_, __) => const MaterialPage(child: RoutineScreen()),
        routes: [
          GoRoute(
            path: 'new',
            pageBuilder: (_, __) => const MaterialPage(child: TaskFormScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, __) => const MaterialPage(child: SettingsScreen()),
      ),
      GoRoute(
        path: '/categories',
        pageBuilder: (_, __) => const MaterialPage(child: CategoriesScreen()),
      ),
      GoRoute(
        path: '/backup',
        pageBuilder: (_, __) => const MaterialPage(child: BackupScreen()),
      ),
    ],
  );
});
