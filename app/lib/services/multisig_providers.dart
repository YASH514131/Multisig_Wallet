import 'dart:convert' as convert;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/base58.dart';
// ignore: implementation_imports
import 'package:solana/src/rpc/dto/encoding.dart';
// ignore: implementation_imports
import 'package:solana/src/rpc/dto/account_data/binary_account_data.dart';
import 'package:solana/solana.dart' hide lamportsPerSol;

import '../core/config/config_controller.dart';
import 'solana_providers.dart';

// ─── MultisigInfo ────────────────────────────────────────────────────────────
/// Decoded on-chain MultisigAccount data.
class MultisigInfo {
  const MultisigInfo({
    required this.address,
    required this.vaultAddress,
    required this.threshold,
    required this.owners,
    required this.nonce,
    required this.roleMapping,
    required this.vaultBalance,
  });

  final String address;
  final String vaultAddress;
  final int threshold;
  final List<String> owners;
  final int nonce;
  final List<OwnerRole> roleMapping;
  final double vaultBalance; // in SOL
}

class OwnerRole {
  const OwnerRole({
    required this.owner,
    required this.roleIndex,
    required this.monthlyLimit,
  });
  final String owner;
  final int roleIndex;
  final int monthlyLimit;

  String get roleName {
    const names = ['BoardMember', 'FinanceOfficer', 'Auditor'];
    return roleIndex < names.length ? names[roleIndex] : 'Role($roleIndex)';
  }
}

Uint8List _multisigDiscriminator() {
  final digest = sha256
      .convert(convert.utf8.encode('account:MultisigAccount'))
      .bytes;
  return Uint8List.fromList(digest.sublist(0, 8));
}

// ─── Vault Balance Provider ──────────────────────────────────────────────────
final vaultBalanceProvider = FutureProvider<double>((ref) async {
  final config = ref.watch(appConfigProvider).valueOrNull ?? defaultAppConfig;
  if (config.multisigAddress.isEmpty) return 0.0;

  // Use ref.watch() for synchronous providers to set up dependency chain.
  // These must be called before any await.
  final client = ref.watch(multisigClientProvider);
  final rpcService = ref.watch(solanaRpcServiceProvider);

  final vault = await client.vaultPda(config.multisigAddress);
  final lamports = await rpcService.getBalance(vault.pubkey.toBase58());
  return lamports / lamportsPerSol;
});

// ─── MultisigInfo Provider ───────────────────────────────────────────────────
final multisigInfoProvider = FutureProvider<MultisigInfo?>((ref) async {
  final config = ref.watch(appConfigProvider).valueOrNull ?? defaultAppConfig;
  if (config.multisigAddress.isEmpty) return null;

  // Use ref.watch() for synchronous providers before any await.
  final rpc = ref.watch(solanaRpcServiceProvider).client;
  final client = ref.watch(multisigClientProvider);
  final rpcService = ref.watch(solanaRpcServiceProvider);
  final multisigDisc = _multisigDiscriminator();

  // Fetch ONLY the specific multisig account (not all program accounts)
  try {
    final acctResult = await rpc.getAccountInfo(
      config.multisigAddress,
      encoding: Encoding.base64,
      commitment: Commitment.confirmed,
    );

    final account = acctResult.value;
    if (account == null) {
      debugPrint('MultisigInfoProvider: account not found');
      return null;
    }

    final accountData = account.data;
    Uint8List? raw;

    if (accountData is BinaryAccountData) {
      raw = Uint8List.fromList(accountData.data);
    } else {
      debugPrint(
        'MultisigInfoProvider: unexpected data type: ${accountData.runtimeType}',
      );
      return null;
    }

    if (raw.length < 8) return null;

    // Check discriminator
    bool matches = true;
    for (int i = 0; i < 8; i++) {
      if (raw[i] != multisigDisc[i]) {
        matches = false;
        break;
      }
    }
    if (!matches) return null;

    // Decode MultisigAccount
    // Layout: disc(8) → owners(vec<Pubkey>) → threshold(u8) → role_mapping(vec<RoleMapping>) → nonce(u64) → last_reset_unix(i64) → vault_bump(u8)
    var o = 8;

    // owners vec
    if (o + 4 > raw.length) return null;
    final ownersLen = _readU32(raw, o);
    o += 4;
    if (ownersLen > 20 || o + ownersLen * 32 > raw.length) return null;

    final owners = <String>[];
    for (int i = 0; i < ownersLen; i++) {
      owners.add(base58encode(raw.sublist(o, o + 32)));
      o += 32;
    }

    // threshold
    if (o >= raw.length) return null;
    final threshold = raw[o];
    o += 1;

    // role_mapping vec
    if (o + 4 > raw.length) return null;
    final roleMappingLen = _readU32(raw, o);
    o += 4;

    final roleMapping = <OwnerRole>[];
    for (int i = 0; i < roleMappingLen; i++) {
      if (o + 32 + 1 + 8 > raw.length) break;
      final owner = base58encode(raw.sublist(o, o + 32));
      o += 32;
      final roleIndex = raw[o];
      o += 1;
      final monthlyLimit = _readU64(raw, o);
      o += 8;
      roleMapping.add(
        OwnerRole(
          owner: owner,
          roleIndex: roleIndex,
          monthlyLimit: monthlyLimit,
        ),
      );
    }

    // nonce
    int nonce = 0;
    if (o + 8 <= raw.length) {
      nonce = _readU64(raw, o);
      o += 8;
    }

    // Get vault balance (using pre-captured refs)
    final vault = await client.vaultPda(config.multisigAddress);
    double vaultBalance = 0;
    try {
      final lamports = await rpcService.getBalance(vault.pubkey.toBase58());
      vaultBalance = lamports / lamportsPerSol;
    } catch (e) {
      debugPrint('Failed to fetch vault balance: $e');
    }

    return MultisigInfo(
      address: config.multisigAddress,
      vaultAddress: vault.pubkey.toBase58(),
      threshold: threshold,
      owners: owners,
      nonce: nonce,
      roleMapping: roleMapping,
      vaultBalance: vaultBalance,
    );
  } catch (e) {
    debugPrint('Failed to fetch multisig info: $e');
  }

  return null;
});

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
