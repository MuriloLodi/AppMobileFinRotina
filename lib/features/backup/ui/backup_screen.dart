import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../db/db_provider.dart';
import '../backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportJson() async {
    setState(() => _busy = true);
    try {
      final db = ref.read(dbProvider);
      final service = ref.read(backupServiceProvider);
      final file = await service.exportJson(db);

      await Share.shareXFiles([XFile(file.path)], text: 'Backup Finrotina (JSON)');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final db = ref.read(dbProvider);
      final service = ref.read(backupServiceProvider);
      final file = await service.exportCsvTransactions(db);

      await Share.shareXFiles([XFile(file.path)], text: 'Lançamentos (CSV)');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreJson() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: const Text('Isso vai APAGAR os dados atuais e aplicar o backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar')),
        ],
      ),
    );

    if (ok != true) return;

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (res == null || res.files.isEmpty) return;

    final path = res.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      final content = await File(path).readAsString();

      final db = ref.read(dbProvider);
      final service = ref.read(backupServiceProvider);
      await service.restoreFromJsonString(db, content);

      _snack('Backup restaurado com sucesso');
    } catch (e) {
      _snack('Erro ao restaurar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup / Restaurar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('Exportar Backup (JSON)'),
                    subtitle: const Text('Inclui categorias, lançamentos, orçamentos e rotina'),
                    onTap: _busy ? null : _exportJson,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.table_chart_outlined),
                    title: const Text('Exportar Lançamentos (CSV)'),
                    subtitle: const Text('CSV para Excel/Google Sheets'),
                    onTap: _busy ? null : _exportCsv,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restaurar Backup (JSON)'),
                subtitle: const Text('Apaga tudo e aplica o conteúdo do backup'),
                onTap: _busy ? null : _restoreJson,
              ),
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
