import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/wallet_account.dart';
import 'wallet_service.dart';

final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

final walletControllerProvider =
    StateNotifierProvider<WalletController, AsyncValue<WalletAccount?>>((ref) {
      final svc = ref.read(walletServiceProvider);
      return WalletController(walletService: svc)..initialize();
    });

class WalletController extends StateNotifier<AsyncValue<WalletAccount?>> {
  WalletController({required WalletService walletService})
    : _walletService = walletService,
      super(const AsyncValue.loading());

  final WalletService _walletService;

  Future<void> initialize() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_walletService.loadExisting);
  }

  Future<void> createNew() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_walletService.createNew);
  }

  Future<void> importMnemonic(String mnemonic) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _walletService.importMnemonic(mnemonic),
    );
  }

  Future<void> clear() async {
    await _walletService.clear();
    state = const AsyncValue.data(null);
  }
}
