import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Service that wraps [LocalAuthentication] for fingerprint / face-ID auth.
///
/// On **web** the service always reports biometrics as unavailable so the
/// lock-screen is never shown.
class BiometricAuthService {
  BiometricAuthService() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  /// Returns `true` when the device supports biometric authentication
  /// **and** at least one biometric is enrolled.  Always `false` on web.
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported) return false;

      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user for biometric authentication.
  /// Returns `true` when the user successfully authenticates.
  Future<bool> authenticate({
    String reason = 'Authenticate to access True Wallet',
  }) async {
    if (kIsWeb) return true; // skip on web
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// Global provider for the biometric auth service.
final biometricAuthServiceProvider = Provider<BiometricAuthService>(
  (_) => BiometricAuthService(),
);
