import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/secure_storage_service.dart';
import 'app_config.dart';

const _configStorageKey = 'app_config_v2';
const _legacyMultisig = '4WWKJNiJzrB8vxNfxxysiq26BRFGiLLsm9f7a271z7BN';
const _legacyMultisig2 = '56BV24CSAibcDzkyAKU9FozGsWAbFSYC8ehAiSYZwst2';
const _legacyMultisig3 = 'no2kn7YMR6BQ91zVk8kzhokcn3R7njJb7fyW9aeKnsx';
const defaultAppConfig = AppConfig(
  rpcUrl: 'https://api.devnet.solana.com',
  programId: 'HqPhVS24ZxhnuS6amTLa4MGuStoUadsjGHdQoih8hn5o',
  multisigAddress: '',
);

final appConfigProvider =
    StateNotifierProvider<ConfigController, AsyncValue<AppConfig>>((ref) {
      return ConfigController(storage: const SecureStorageService())..load();
    });

class ConfigController extends StateNotifier<AsyncValue<AppConfig>> {
  ConfigController({required SecureStorageService storage})
    : _storage = storage,
      super(const AsyncValue.loading());

  final SecureStorageService _storage;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final raw = await _storage.read(_configStorageKey);
      debugPrint('ConfigController.load raw=$raw');
      if (raw == null || raw.isEmpty) {
        debugPrint('ConfigController.load using defaults');
        return defaultAppConfig;
      }

      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        final rpc = map['rpcUrl'] as String? ?? defaultAppConfig.rpcUrl;
        final programId =
            map['programId'] as String? ?? defaultAppConfig.programId;
        final storedMultisig = map['multisigAddress'] as String? ?? '';
        // Clear legacy hardcoded addresses — user must configure their own
        final multisig =
            storedMultisig == _legacyMultisig ||
                storedMultisig == _legacyMultisig2 ||
                storedMultisig == _legacyMultisig3
            ? ''
            : storedMultisig;

        debugPrint(
          'ConfigController.load parsed: rpc=$rpc programId=$programId multisig=$multisig',
        );
        return AppConfig(
          rpcUrl: rpc,
          programId: programId,
          multisigAddress: multisig,
        );
      } catch (e) {
        debugPrint('ConfigController.load error: $e');
        return defaultAppConfig;
      }
    });
  }

  Future<void> update({
    String? rpcUrl,
    String? programId,
    String? multisigAddress,
  }) async {
    final current = state.valueOrNull ?? defaultAppConfig;
    final next = current.copyWith(
      rpcUrl: rpcUrl,
      programId: programId,
      multisigAddress: multisigAddress,
    );
    state = AsyncValue.data(next);
    final payload = json.encode({
      'rpcUrl': next.rpcUrl,
      'programId': next.programId,
      'multisigAddress': next.multisigAddress,
    });
    await _storage.write(key: _configStorageKey, value: payload);
    debugPrint('ConfigController.update saved: $payload');
  }
}
