import 'dart:convert' as convert;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart';
// ignore: implementation_imports
import 'package:solana/src/rpc/dto/encoding.dart';

import '../core/config/app_config.dart';
import '../domain/entities/proposal.dart';
import '../domain/entities/proposal_action.dart';
import 'multisig_client.dart';
import 'wallet_service.dart';

class ProposalService {
  ProposalService({
    required RpcClient rpc,
    required AppConfig config,
    required MultisigClient client,
  }) : _rpc = rpc,
       _config = config,
       _client = client,
       _proposalDisc = _discriminator('account:Proposal');

  final RpcClient _rpc;
  final AppConfig _config;
  final MultisigClient _client;
  final Uint8List _proposalDisc;

  Future<List<Proposal>> fetchProposals() async {
    if (_config.multisigAddress.isEmpty) {
      throw StateError('Multisig address not set in settings');
    }

    debugPrint(
      'Fetching proposals for multisig ${_config.multisigAddress} '
      'program ${_config.programId}',
    );

    // Fetch all program accounts (no server-side filters - client-side filter later)
    final accounts = await _rpc.getProgramAccounts(
      _config.programId,
      encoding: Encoding.base64,
      commitment: Commitment.confirmed,
    );

    debugPrint('Fetched ${accounts.length} program accounts');

    final list = <Proposal>[];
    for (final acct in accounts) {
      debugPrint('Processing account ${acct.pubkey}');
      final dynamic dataField = acct.account.data;
      debugPrint('  dataField type: ${dataField.runtimeType}');

      Uint8List? raw;

      // Handle different data formats
      if (dataField is List) {
        // Could be base64 tuple [string, encoding] or raw bytes
        if (dataField.isNotEmpty && dataField.first is String) {
          // Base64 encoded: ["base64string", "base64"]
          raw = Uint8List.fromList(
            convert.base64.decode(dataField.first as String),
          );
          debugPrint('  decoded from base64, length: ${raw.length}');
        } else if (dataField.isNotEmpty && dataField.first is int) {
          // Already raw bytes
          raw = Uint8List.fromList(dataField.cast<int>());
          debugPrint('  raw bytes from List<int>, length: ${raw.length}');
        }
      } else {
        // BinaryAccountData or similar wrapper
        final dynamic maybeData = dataField?.data;
        if (maybeData is List && maybeData.isNotEmpty) {
          if (maybeData.first is int) {
            // Raw bytes in .data property
            raw = Uint8List.fromList(maybeData.cast<int>());
            debugPrint(
              '  raw bytes from dataField.data, length: ${raw.length}',
            );
          } else if (maybeData.first is String) {
            raw = Uint8List.fromList(
              convert.base64.decode(maybeData.first as String),
            );
            debugPrint(
              '  decoded from dataField.data base64, length: ${raw.length}',
            );
          }
        }
      }

      if (raw == null || raw.isEmpty) {
        debugPrint('  -> no raw data, skipping');
        continue;
      }

      final parsed =
          _decodeProposal(raw, acct.pubkey) ??
          _decodeProposal(raw, acct.pubkey, ignoreDiscriminator: true);

      if (parsed != null) {
        // Client-side filter: only include proposals for our multisig
        if (parsed.multisig == _config.multisigAddress) {
          list.add(parsed);
          debugPrint(
            'Added proposal id=${parsed.id} multisig=${parsed.multisig}',
          );
        } else {
          debugPrint(
            'Skipped proposal: multisig mismatch ${parsed.multisig} != ${_config.multisigAddress}',
          );
        }
      } else {
        // Debug why decode failed
        final discHex = raw
            .take(8)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        final expectHex = _proposalDisc
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        debugPrint(
          'Skipped acct ${acct.pubkey} len=${raw.length} disc=$discHex expected=$expectHex',
        );
      }
    }
    debugPrint('Decoded ${list.length} proposals for UI');
    return list;
  }

  Future<Proposal?> fetchById(String id) async {
    final items = await fetchProposals();
    for (final p in items) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<String> approve({
    required int proposalId,
    required WalletService wallet,
  }) async {
    return _client.approveProposal(
      multisig: _config.multisigAddress,
      proposalId: proposalId,
      wallet: wallet,
    );
  }

  Future<String> execute({
    required int proposalId,
    required String destination,
    required WalletService wallet,
  }) async {
    return _client.executeProposal(
      multisig: _config.multisigAddress,
      proposalId: proposalId,
      destination: destination,
      wallet: wallet,
    );
  }

  /// Execute a governance proposal by dispatching to the correct
  /// on-chain instruction based on the proposal's [action] type.
  Future<String> executeGovernance({
    required int proposalId,
    required ProposalAction action,
    required WalletService wallet,
  }) async {
    final multisig = _config.multisigAddress;
    return switch (action) {
      AddOwnerAction(:final newOwner) => _client.addOwner(
        multisig: multisig,
        proposalId: proposalId,
        newOwner: newOwner,
        wallet: wallet,
      ),
      RemoveOwnerAction(:final owner) => _client.removeOwner(
        multisig: multisig,
        proposalId: proposalId,
        owner: owner,
        wallet: wallet,
      ),
      UpdateThresholdAction(:final newThreshold) => _client.updateThreshold(
        multisig: multisig,
        proposalId: proposalId,
        newThreshold: newThreshold,
        wallet: wallet,
      ),
      UpdateRoleAction(:final owner, :final roleIndex) => _client.updateRole(
        multisig: multisig,
        proposalId: proposalId,
        owner: owner,
        roleIndex: roleIndex,
        wallet: wallet,
      ),
      UpdateMonthlyLimitAction(:final owner, :final newLimit) =>
        _client.updateMonthlyLimit(
          multisig: multisig,
          proposalId: proposalId,
          owner: owner,
          newLimit: newLimit,
          wallet: wallet,
        ),
      TransferAction() => throw StateError(
        'TransferAction is not a governance action — use execute() instead',
      ),
    };
  }

  Future<String> create({
    required String destination,
    required int amountLamports,
    required int expiresAt,
    required int proposalId,
    required ProposalAction action,
    required WalletService wallet,
  }) async {
    if (_config.multisigAddress.isEmpty) {
      throw StateError('Multisig address not set in settings');
    }

    return _client.createProposal(
      multisig: _config.multisigAddress,
      destination: destination,
      amount: amountLamports,
      expiresAt: expiresAt,
      proposalId: proposalId,
      action: action,
      wallet: wallet,
    );
  }

  Proposal? _decodeProposal(
    Uint8List data,
    String accountPubkey, {
    bool ignoreDiscriminator = false,
  }) {
    try {
      debugPrint(
        '_decodeProposal $accountPubkey len=${data.length} ignoreDisc=$ignoreDiscriminator',
      );
      if (data.length < 8) {
        debugPrint('  -> too short');
        return null;
      }
      if (!ignoreDiscriminator && !_matches(data, _proposalDisc)) {
        debugPrint('  -> discriminator mismatch');
        return null;
      }
      var o = 8; // skip discriminator

      String readPk() {
        if (o + 32 > data.length) {
          throw RangeError('readPk out of bounds at $o');
        }
        final slice = data.sublist(o, o + 32);
        o += 32;
        return base58encode(slice);
      }

      final proposer = readPk();
      final multisig = readPk();
      final destination = readPk();
      debugPrint(
        '  -> proposer=$proposer multisig=$multisig dest=$destination',
      );

      if (o + 8 > data.length) {
        debugPrint('  -> not enough data for amount');
        return null;
      }
      final amount = _readU64(data, o);
      o += 8;

      if (o + 4 > data.length) return null;
      final approvalsLen = _readU32(data, o);
      o += 4;

      // Sanity check approvals length
      if (approvalsLen > 20 || o + approvalsLen * 32 > data.length) return null;

      final approvals = <String>[];
      for (int i = 0; i < approvalsLen; i++) {
        approvals.add(base58encode(data.sublist(o, o + 32)));
        o += 32;
      }

      if (o + 1 + 8 + 8 + 8 + 1 + 1 > data.length) return null;

      final executed = data[o] != 0;
      o += 1;
      final createdAt = _readI64(data, o);
      o += 8;
      final expiresAt = _readI64(data, o);
      o += 8;
      final id = _readU64(data, o);
      o += 8;
      final bump = data[o];
      o += 1;

      // Decode ProposalAction enum (replaces old `isGovernance` bool)
      final (action, actionLen) = ProposalAction.deserialize(data, o);
      o += actionLen;

      return Proposal(
        id: id.toString(),
        destination: destination,
        amountLamports: amount,
        approvals: approvals,
        executed: executed,
        proposer: proposer,
        multisig: multisig,
        bump: bump,
        action: action,
        createdAt: createdAt,
        expiresAt: expiresAt,
        accountPubkey: accountPubkey,
      );
    } catch (e) {
      debugPrint('_decodeProposal error for $accountPubkey: $e');
      return null;
    }
  }

  bool _matches(Uint8List data, Uint8List disc) {
    for (int i = 0; i < disc.length; i++) {
      if (data[i] != disc[i]) return false;
    }
    return true;
  }
}

Uint8List _discriminator(String name) {
  final digest = sha256.convert(convert.utf8.encode(name)).bytes;
  return Uint8List.fromList(digest.sublist(0, 8));
}

int _readU64(Uint8List data, int offset) {
  BigInt v = BigInt.zero;
  for (int i = 0; i < 8; i++) {
    v |= BigInt.from(data[offset + i]) << (8 * i);
  }
  return v.toInt();
}

int _readU32(Uint8List data, int offset) {
  int v = 0;
  for (int i = 0; i < 4; i++) {
    v |= data[offset + i] << (8 * i);
  }
  return v;
}

int _readI64(Uint8List data, int offset) {
  BigInt v = BigInt.zero;
  for (int i = 0; i < 8; i++) {
    v |= BigInt.from(data[offset + i]) << (8 * i);
  }
  final two64 = BigInt.one << 64;
  final two63 = BigInt.one << 63;
  if (v >= two63) {
    v = v - two64;
  }
  return v.toInt();
}
