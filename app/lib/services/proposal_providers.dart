import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/proposal.dart';
import '../core/config/config_controller.dart';
import 'proposal_service.dart';
import 'solana_providers.dart';

final proposalServiceProvider = Provider<ProposalService>((ref) {
  final rpc = ref.watch(solanaRpcServiceProvider).client;
  final config = ref.watch(appConfigProvider).valueOrNull ?? defaultAppConfig;
  final client = ref.watch(multisigClientProvider);
  return ProposalService(rpc: rpc, config: config, client: client);
});

final proposalsProvider = FutureProvider<List<Proposal>>((ref) async {
  // Watch config so provider rebuilds when config finishes loading
  final configState = ref.watch(appConfigProvider);
  final config = configState.valueOrNull;
  // Return empty while config is loading or no multisig configured
  if (config == null || config.multisigAddress.isEmpty) return [];
  final svc = ref.read(proposalServiceProvider);
  return svc.fetchProposals();
});

final proposalByIdProvider = FutureProvider.family<Proposal?, String>((
  ref,
  id,
) async {
  return ref.read(proposalServiceProvider).fetchById(id);
});
