import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../security/security_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _snack(BuildContext context, String msg) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sec = ref.watch(securityServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text('Categorias'),
                  subtitle: const Text('Criar/editar categorias de entrada e saída'),
                  onTap: () => context.push('/categories'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: const Text('Orçamentos'),
                  subtitle: const Text('Defina orçamento por categoria (mês atual)'),
                  onTap: () => context.push('/finance/budgets'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup / Restaurar'),
                  subtitle: const Text('Exportar JSON/CSV e restaurar (apaga e aplica)'),
                  onTap: () => context.push('/backup'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Segurança (PIN)'),
                  subtitle: const Text('PIN obrigatório, biometria opcional'),
                ),
                const Divider(height: 1),

                FutureBuilder<bool>(
                  future: sec.hasPin(),
                  builder: (context, snapHas) {
                    final hasPin = snapHas.data ?? false;

                    return ListTile(
                      leading: const Icon(Icons.password),
                      title: Text(hasPin ? 'Alterar PIN' : 'Criar PIN'),
                      onTap: () {
                        if (hasPin) {
                          context.push('/lock?mode=change');
                        } else {
                          context.push('/lock?mode=setup');
                        }
                      },
                    );
                  },
                ),

                const Divider(height: 1),

                FutureBuilder<List<dynamic>>(
                  future: Future.wait([
                    sec.hasPin(),
                    sec.canUseBiometrics(),
                    sec.isBiometricsEnabled(),
                  ]),
                  builder: (context, snap) {
                    final data = snap.data;
                    final hasPin = (data != null && data[0] == true);
                    final canBio = (data != null && data[1] == true);
                    final enabled = (data != null && data[2] == true);

                    return SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: const Text('Biometria'),
                      subtitle: Text(
                        !hasPin
                            ? 'Crie um PIN primeiro'
                            : !canBio
                                ? 'Dispositivo sem biometria disponível'
                                : 'Usar biometria no desbloqueio',
                      ),
                      value: enabled,
                      onChanged: (!hasPin || !canBio)
                          ? null
                          : (v) async {
                              await sec.setBiometricsEnabled(v);
                              if (context.mounted) {
                                _snack(context, v ? 'Biometria ativada' : 'Biometria desativada');
                              }
                            },
                    );
                  },
                ),

                const Divider(height: 1),

                FutureBuilder<bool>(
                  future: sec.hasPin(),
                  builder: (context, snap) {
                    final hasPin = snap.data ?? false;
                    if (!hasPin) return const SizedBox.shrink();

                    return ListTile(
                      leading: const Icon(Icons.lock_open),
                      title: const Text('Desativar bloqueio'),
                      subtitle: const Text('Remove o PIN e desativa a tela de bloqueio'),
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Desativar bloqueio?'),
                            content: const Text('Isso removerá o PIN do app.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Desativar')),
                            ],
                          ),
                        );

                        if (ok == true) {
                          await sec.clearPin();
                          if (context.mounted) _snack(context, 'Bloqueio desativado');
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Sincronização'),
              subtitle: const Text('Em breve (Firebase/Supabase)'),
              onTap: () => _snack(context, 'Sincronização: vamos ativar quando você quiser (Firebase/Supabase).'),
            ),
          ),
        ],
      ),
    );
  }
}
