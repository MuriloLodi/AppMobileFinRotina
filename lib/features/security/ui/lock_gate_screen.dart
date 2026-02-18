import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../security_service.dart';

class LockGateScreen extends ConsumerStatefulWidget {
  const LockGateScreen({super.key});

  @override
  ConsumerState<LockGateScreen> createState() => _LockGateScreenState();
}

class _LockGateScreenState extends ConsumerState<LockGateScreen> {
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _go();
  }

  Future<void> _go() async {
    if (_navigated) return;
    _navigated = true;

    final sec = ref.read(securityServiceProvider);
    final hasPin = await sec.hasPin();

    if (!mounted) return;

    if (hasPin) {
      context.go('/lock?mode=unlock');
    } else {
      context.go('/finance');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
