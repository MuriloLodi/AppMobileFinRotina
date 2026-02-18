import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../security_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pinController = TextEditingController();
  final _pin2Controller = TextEditingController();

  String _stepInfo = '';
  String _firstPin = '';
  bool _busy = false;

  @override
  void dispose() {
    _pinController.dispose();
    _pin2Controller.dispose();
    super.dispose();
  }

  String _mode(BuildContext context) {
    final qp = GoRouterState.of(context).uri.queryParameters;
    return qp['mode'] ?? 'unlock'; // unlock | setup | change
  }

  bool _isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  Future<void> _showMsg(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode(context);
    final sec = ref.watch(securityServiceProvider);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            mode == 'unlock'
                ? 'Desbloquear'
                : mode == 'change'
                    ? 'Alterar PIN'
                    : 'Criar PIN',
          ),
          automaticallyImplyLeading: false,
        ),
        body: FutureBuilder<bool>(
          future: Future.wait([
            sec.hasPin(),
            sec.isBiometricsEnabled(),
            sec.canUseBiometrics(),
          ]).then((v) => (v[0] as bool)),
          builder: (context, snap) {
            // snap só pra evitar "build antes do storage"
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (_stepInfo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_stepInfo),
                    ),

                  if (mode == 'setup') ..._buildSetup(),
                  if (mode == 'change') ..._buildChange(),
                  if (mode == 'unlock') ..._buildUnlock(sec),

                  const SizedBox(height: 12),

                  if (_busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildUnlock(SecurityService sec) {
    return [
      const Text('Digite seu PIN para acessar'),
      const SizedBox(height: 12),
      TextField(
        controller: _pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 6,
        decoration: const InputDecoration(labelText: 'PIN (4 a 6 dígitos)'),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                final pin = _pinController.text.trim();
                if (!_isValidPin(pin)) {
                  _showMsg('PIN inválido');
                  return;
                }
                setState(() => _busy = true);
                final ok = await sec.verifyPin(pin);
                setState(() => _busy = false);

                if (!mounted) return;
                if (ok) {
                  context.go('/finance');
                } else {
                  _showMsg('PIN incorreto');
                }
              },
        child: const Text('Entrar'),
      ),
      const SizedBox(height: 12),
      FutureBuilder(
        future: Future.wait([sec.isBiometricsEnabled(), sec.canUseBiometrics()]),
        builder: (context, snap) {
          final data = snap.data as List<dynamic>?;
          final enabled = data != null && data[0] == true;
          final can = data != null && data[1] == true;

          if (!enabled || !can) return const SizedBox.shrink();

          return OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final ok = await sec.authenticateBiometrics();
                    setState(() => _busy = false);

                    if (!mounted) return;
                    if (ok) context.go('/finance');
                  },
            icon: const Icon(Icons.fingerprint),
            label: const Text('Usar biometria'),
          );
        },
      ),
    ];
  }

  List<Widget> _buildSetup() {
    return [
      const Text('Crie um PIN (4 a 6 dígitos). Ele será obrigatório para acessar o app.'),
      const SizedBox(height: 12),

      if (_firstPin.isEmpty) ...[
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Novo PIN'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final p = _pinController.text.trim();
                  if (!_isValidPin(p)) {
                    _showMsg('PIN inválido (4 a 6 dígitos)');
                    return;
                  }
                  setState(() {
                    _firstPin = p;
                    _pinController.clear();
                    _stepInfo = 'Confirme o PIN';
                  });
                },
          child: const Text('Continuar'),
        ),
      ] else ...[
        TextField(
          controller: _pin2Controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Confirmar PIN'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final p2 = _pin2Controller.text.trim();
                  if (p2 != _firstPin) {
                    _showMsg('PIN não confere');
                    return;
                  }
                  setState(() => _busy = true);
                  await ref.read(securityServiceProvider).setPin(_firstPin);
                  setState(() => _busy = false);

                  if (!mounted) return;
                  context.go('/finance');
                },
          child: const Text('Salvar PIN'),
        ),
      ],
    ];
  }

  List<Widget> _buildChange() {
    final sec = ref.read(securityServiceProvider);

    return [
      const Text('Informe o PIN atual e depois defina o novo PIN.'),
      const SizedBox(height: 12),

      if (_firstPin.isEmpty) ...[
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN atual'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final cur = _pinController.text.trim();
                  if (!_isValidPin(cur)) {
                    _showMsg('PIN inválido');
                    return;
                  }
                  setState(() => _busy = true);
                  final ok = await sec.verifyPin(cur);
                  setState(() => _busy = false);

                  if (!ok) {
                    _showMsg('PIN atual incorreto');
                    return;
                  }

                  setState(() {
                    _firstPin = 'verified';
                    _pinController.clear();
                    _pin2Controller.clear();
                    _stepInfo = 'Digite o novo PIN';
                  });
                },
          child: const Text('Validar PIN'),
        ),
      ] else ...[
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Novo PIN'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pin2Controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Confirmar novo PIN'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final p1 = _pinController.text.trim();
                  final p2 = _pin2Controller.text.trim();
                  if (!_isValidPin(p1)) {
                    _showMsg('Novo PIN inválido (4 a 6 dígitos)');
                    return;
                  }
                  if (p1 != p2) {
                    _showMsg('PIN não confere');
                    return;
                  }

                  setState(() => _busy = true);
                  await sec.setPin(p1);
                  setState(() => _busy = false);

                  if (!mounted) return;
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN alterado com sucesso')),
                  );
                },
          child: const Text('Salvar novo PIN'),
        ),
      ],
    ];
  }
}
