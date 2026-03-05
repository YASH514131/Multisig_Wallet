import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/biometric/biometric_lock_screen.dart';
import 'services/biometric_auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TrueWalletApp()));
}

class TrueWalletApp extends ConsumerWidget {
  const TrueWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'True Wallet',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: kIsWeb ? _AuthenticatedApp() : _BiometricGate(),
    );
  }
}

/// On mobile, checks if biometrics are available and shows the lock screen
/// before revealing the main app.  On web this is never used.
class _BiometricGate extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<_BiometricGate> {
  bool _authenticated = false;
  bool _checking = true;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final bioService = ref.read(biometricAuthServiceProvider);
    final available = await bioService.isBiometricAvailable();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _checking = false;
      // If device has no biometric enrolled, skip the lock screen.
      if (!available) _authenticated = true;
    });
  }

  void _onAuthenticated() {
    setState(() => _authenticated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_authenticated && _biometricAvailable) {
      return BiometricLockScreen(onAuthenticated: _onAuthenticated);
    }

    return _AuthenticatedApp();
  }
}

/// The actual router-driven app, shown after authentication.
class _AuthenticatedApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'True Wallet',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
