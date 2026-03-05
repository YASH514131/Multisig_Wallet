import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/config_controller.dart';
import 'multisig_client.dart';
import 'solana_rpc_service.dart';
import 'wallet_controller.dart';

const int lamportsPerSol = 1000000000;

final solanaRpcServiceProvider = Provider<SolanaRpcService>((ref) {
  final configState = ref.watch(appConfigProvider);
  final rpcUrl = configState.valueOrNull?.rpcUrl ?? defaultAppConfig.rpcUrl;
  return SolanaRpcService(rpcUrl: rpcUrl);
});

final multisigClientProvider = Provider<MultisigClient>((ref) {
  final configState = ref.watch(appConfigProvider);
  final config = configState.valueOrNull ?? defaultAppConfig;
  return MultisigClient(config: config);
});

final balanceProvider = FutureProvider<double>((ref) async {
  final walletState = ref.watch(walletControllerProvider);
  final wallet = walletState.valueOrNull;
  if (wallet == null) {
    throw StateError('No wallet loaded');
  }

  final rpcService = ref.watch(solanaRpcServiceProvider);
  final lamports = await rpcService.getBalance(wallet.address);
  return lamports / lamportsPerSol;
});
