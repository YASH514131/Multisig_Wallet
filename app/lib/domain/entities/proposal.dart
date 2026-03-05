import 'proposal_action.dart';

class Proposal {
  const Proposal({
    required this.id,
    required this.destination,
    required this.amountLamports,
    this.approvals = const [],
    this.executed = false,
    this.proposer = '',
    this.multisig = '',
    this.bump = 0,
    this.action = const TransferAction(),
    this.createdAt = 0,
    this.expiresAt = 0,
    this.accountPubkey = '',
  });

  final String id;
  final String destination;
  final int amountLamports;
  final List<String> approvals;
  final bool executed;
  final String proposer;
  final String multisig;
  final int bump;

  /// The exact action this proposal authorises.
  final ProposalAction action;

  /// Convenience getter – `true` when this is any governance action.
  bool get isGovernance => action.isGovernance;

  final int createdAt;
  final int expiresAt;
  final String accountPubkey;
}
