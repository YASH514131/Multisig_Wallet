import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../core/config/app_config.dart';
import '../domain/entities/proposal_action.dart';
import 'wallet_service.dart';

/// Minimal Anchor-compatible client for the true_wallet_multisig program.
class MultisigClient {
  MultisigClient({required this.config})
    : _programId = Ed25519HDPublicKey.fromBase58(config.programId),
      _rpc = RpcClient(config.rpcUrl);

  final AppConfig config;
  final Ed25519HDPublicKey _programId;
  final RpcClient _rpc;
  static final Ed25519HDPublicKey _clockSysvar = Ed25519HDPublicKey.fromBase58(
    'SysvarC1ock11111111111111111111111111111111',
  );

  /// Derive the vault PDA: seeds = ["vault", multisig]
  Future<ProgramPda> vaultPda(String multisig) async {
    final multisigKey = Ed25519HDPublicKey.fromBase58(multisig);
    final pda = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        Uint8List.fromList(utf8.encode('vault')),
        Uint8List.fromList(multisigKey.bytes),
      ],
      programId: _programId,
    );
    return ProgramPda(pda, 0);
  }

  /// Derive a proposal PDA: seeds = ["proposal", multisig, proposalId.to_le_bytes()]
  Future<ProgramPda> proposalPda({
    required String multisig,
    required int proposalId,
  }) async {
    final multisigKey = Ed25519HDPublicKey.fromBase58(multisig);
    final idBytes = _u64le(proposalId);
    final pda = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        Uint8List.fromList(utf8.encode('proposal')),
        Uint8List.fromList(multisigKey.bytes),
        idBytes,
      ],
      programId: _programId,
    );
    return ProgramPda(pda, 0);
  }

  /// Initialize a multisig and its vault PDA.
  Future<String> initializeMultisig({
    required List<String> owners,
    required int threshold,
    required List<RoleInputArgs> roleMapping,
    required WalletService wallet,
  }) async {
    final kp = await wallet.loadKeypair();
    final multisig = await Ed25519HDKeyPair.random();
    final vault = await vaultPda(multisig.publicKey.toBase58());

    final data = _buildInstructionData('initialize_multisig', [
      _encodeVecPubkeys(owners),
      Uint8List.fromList([threshold]),
      _encodeRoleInputs(roleMapping),
    ]);

    final ix = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: multisig.publicKey, isSigner: true),
        AccountMeta.writeable(pubKey: vault.pubkey, isSigner: false),
        AccountMeta.writeable(pubKey: kp.publicKey, isSigner: true),
        AccountMeta(
          pubKey: SystemProgram.id,
          isSigner: false,
          isWriteable: false,
        ),
        AccountMeta.readonly(pubKey: _clockSysvar, isSigner: false),
      ],
      data: data,
    );

    final message = Message.only(ix);
    final tx = await _rpc.signAndSendTransaction(message, [kp, multisig]);
    return tx;
  }

  /// Create proposal (transfer or governance).
  Future<String> createProposal({
    required String multisig,
    required String destination,
    required int amount,
    required int expiresAt,
    required int proposalId,
    required ProposalAction action,
    required WalletService wallet,
  }) async {
    final kp = await wallet.loadKeypair();
    final multisigKey = Ed25519HDPublicKey.fromBase58(multisig);
    final proposal = await proposalPda(
      multisig: multisig,
      proposalId: proposalId,
    );

    final data = _buildInstructionData('create_proposal', [
      Uint8List.fromList(Ed25519HDPublicKey.fromBase58(destination).bytes),
      _u64le(amount),
      _i64le(expiresAt),
      _u64le(proposalId),
      action.serialize(),
    ]);

    final ix = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: multisigKey, isSigner: false),
        AccountMeta.writeable(pubKey: proposal.pubkey, isSigner: false),
        AccountMeta.writeable(pubKey: kp.publicKey, isSigner: true),
        AccountMeta(
          pubKey: SystemProgram.id,
          isSigner: false,
          isWriteable: false,
        ),
        AccountMeta.readonly(pubKey: _clockSysvar, isSigner: false),
      ],
      data: data,
    );

    final message = Message.only(ix);
    return _rpc.signAndSendTransaction(message, [kp]);
  }

  /// Approve an existing proposal.
  Future<String> approveProposal({
    required String multisig,
    required int proposalId,
    required WalletService wallet,
  }) async {
    final kp = await wallet.loadKeypair();
    final multisigKey = Ed25519HDPublicKey.fromBase58(multisig);
    final proposal = await proposalPda(
      multisig: multisig,
      proposalId: proposalId,
    );

    final data = _buildInstructionData('approve_proposal', []);

    final ix = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: multisigKey, isSigner: false),
        AccountMeta.writeable(pubKey: proposal.pubkey, isSigner: false),
        AccountMeta.readonly(pubKey: kp.publicKey, isSigner: true),
      ],
      data: data,
    );

    final message = Message.only(ix);
    return _rpc.signAndSendTransaction(message, [kp]);
  }

  /// Execute a transfer proposal (non-governance).
  Future<String> executeProposal({
    required String multisig,
    required int proposalId,
    required String destination,
    required WalletService wallet,
  }) async {
    final kp = await wallet.loadKeypair();
    final multisigKey = Ed25519HDPublicKey.fromBase58(multisig);
    final proposal = await proposalPda(
      multisig: multisig,
      proposalId: proposalId,
    );
    final vault = await vaultPda(multisig);
    final destKey = Ed25519HDPublicKey.fromBase58(destination);

    final data = _buildInstructionData('execute_proposal', []);

    final ix = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: multisigKey, isSigner: false),
        AccountMeta.writeable(pubKey: proposal.pubkey, isSigner: false),
        AccountMeta.writeable(pubKey: vault.pubkey, isSigner: false),
        AccountMeta.writeable(pubKey: destKey, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: _clockSysvar, isSigner: false),
        AccountMeta.readonly(pubKey: kp.publicKey, isSigner: true),
      ],
      data: data,
    );

    final message = Message.only(ix);
    return _rpc.signAndSendTransaction(message, [kp]);
  }

  /// Governance updates share the same pattern; below is threshold as an example.
  Future<String> updateThreshold({
    required String multisig,
    required int proposalId,
    required int newThreshold,
    required WalletService wallet,
  }) async {
    return _governanceInstruction(
      name: 'update_threshold',
      multisig: multisig,
      proposalId: proposalId,
      payload: [
        Uint8List.fromList([newThreshold]),
      ],
      wallet: wallet,
    );
  }

  /// Add a new owner to the multisig.
  Future<String> addOwner({
    required String multisig,
    required int proposalId,
    required String newOwner,
    required WalletService wallet,
  }) async {
    return _governanceInstruction(
      name: 'add_owner',
      multisig: multisig,
      proposalId: proposalId,
      payload: [
        Uint8List.fromList(Ed25519HDPublicKey.fromBase58(newOwner).bytes),
      ],
      wallet: wallet,
    );
  }

  /// Remove an owner from the multisig.
  Future<String> removeOwner({
    required String multisig,
    required int proposalId,
    required String owner,
    required WalletService wallet,
  }) async {
    return _governanceInstruction(
      name: 'remove_owner',
      multisig: multisig,
      proposalId: proposalId,
      payload: [Uint8List.fromList(Ed25519HDPublicKey.fromBase58(owner).bytes)],
      wallet: wallet,
    );
  }

  /// Update a member's role.
  Future<String> updateRole({
    required String multisig,
    required int proposalId,
    required String owner,
    required int roleIndex,
    required WalletService wallet,
  }) async {
    return _governanceInstruction(
      name: 'update_role',
      multisig: multisig,
      proposalId: proposalId,
      payload: [
        Uint8List.fromList(Ed25519HDPublicKey.fromBase58(owner).bytes),
        Uint8List.fromList([roleIndex]),
      ],
      wallet: wallet,
    );
  }

  /// Update an owner's monthly spending limit.
  Future<String> updateMonthlyLimit({
    required String multisig,
    required int proposalId,
    required String owner,
    required int newLimit,
    required WalletService wallet,
  }) async {
    return _governanceInstruction(
      name: 'update_monthly_limit',
      multisig: multisig,
      proposalId: proposalId,
      payload: [
        Uint8List.fromList(Ed25519HDPublicKey.fromBase58(owner).bytes),
        _u64le(newLimit),
      ],
      wallet: wallet,
    );
  }

  /// Send SOL from the user's own wallet (NOT the vault).
  Future<String> sendSol({
    required String recipient,
    required int lamports,
    required WalletService wallet,
  }) async {
    final kp = await wallet.loadKeypair();
    final recipientKey = Ed25519HDPublicKey.fromBase58(recipient);

    final ix = SystemInstruction.transfer(
      fundingAccount: kp.publicKey,
      recipientAccount: recipientKey,
      lamports: lamports,
    );

    final message = Message.only(ix);
    return _rpc.signAndSendTransaction(message, [kp]);
  }

  /// Returns the multisig account address created on-chain.
  Future<InitMultisigResult> initializeMultisigWithResult({
    required List<String> owners,
    required int threshold,
    required List<RoleInputArgs> roleMapping,
    required WalletService wallet,
  }) async {
    final kp = await wallet.loadKeypair();
    final multisig = await Ed25519HDKeyPair.random();
    final vault = await vaultPda(multisig.publicKey.toBase58());

    final data = _buildInstructionData('initialize_multisig', [
      _encodeVecPubkeys(owners),
      Uint8List.fromList([threshold]),
      _encodeRoleInputs(roleMapping),
    ]);

    final ix = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: multisig.publicKey, isSigner: true),
        AccountMeta.writeable(pubKey: vault.pubkey, isSigner: false),
        AccountMeta.writeable(pubKey: kp.publicKey, isSigner: true),
        AccountMeta(
          pubKey: SystemProgram.id,
          isSigner: false,
          isWriteable: false,
        ),
        AccountMeta.readonly(pubKey: _clockSysvar, isSigner: false),
      ],
      data: data,
    );

    final message = Message.only(ix);
    final txSig = await _rpc.signAndSendTransaction(message, [kp, multisig]);

    return InitMultisigResult(
      txSignature: txSig,
      multisigAddress: multisig.publicKey.toBase58(),
      vaultAddress: vault.pubkey.toBase58(),
    );
  }

  /// Shared helper for governance-type instructions (GovernanceUpdate context).
  Future<String> _governanceInstruction({
    required String name,
    required String multisig,
    required int proposalId,
    required List<Uint8List> payload,
    required WalletService wallet,
  }) async {
    final kp = await wallet.loadKeypair();
    final multisigKey = Ed25519HDPublicKey.fromBase58(multisig);
    final proposal = await proposalPda(
      multisig: multisig,
      proposalId: proposalId,
    );

    final data = _buildInstructionData(name, payload);

    final ix = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: multisigKey, isSigner: false),
        AccountMeta.writeable(pubKey: proposal.pubkey, isSigner: false),
        AccountMeta.readonly(pubKey: kp.publicKey, isSigner: true),
        AccountMeta.readonly(pubKey: _clockSysvar, isSigner: false),
      ],
      data: data,
    );

    final message = Message.only(ix);
    return _rpc.signAndSendTransaction(message, [kp]);
  }

  // ---------- Helpers ----------

  ByteArray _buildInstructionData(String name, List<Uint8List> parts) {
    final discriminator = _discriminator('global:$name');
    final buffer = BytesBuilder(copy: false);
    buffer.add(discriminator);
    for (final p in parts) {
      buffer.add(p);
    }
    return ByteArray(buffer.toBytes());
  }

  Uint8List _discriminator(String name) {
    final hash = sha256.convert(utf8.encode(name)).bytes;
    return Uint8List.fromList(hash.take(8).toList());
  }

  Uint8List _encodeVecPubkeys(List<String> keys) {
    final buf = BytesBuilder(copy: false);
    final len = Uint8List(4)
      ..buffer.asByteData().setUint32(0, keys.length, Endian.little);
    buf.add(len);
    for (final k in keys) {
      buf.add(Ed25519HDPublicKey.fromBase58(k).bytes);
    }
    return buf.toBytes();
  }

  Uint8List _encodeRoleInputs(List<RoleInputArgs> roles) {
    final buf = BytesBuilder(copy: false);
    final len = Uint8List(4)
      ..buffer.asByteData().setUint32(0, roles.length, Endian.little);
    buf.add(len);
    for (final r in roles) {
      buf.add(Ed25519HDPublicKey.fromBase58(r.owner).bytes);
      buf.add(Uint8List.fromList([r.roleIndex]));
      buf.add(_u64le(r.monthlyLimit));
    }
    return buf.toBytes();
  }

  Uint8List _u64le(int value) {
    var v = BigInt.from(value);
    final out = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      out[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return out;
  }

  Uint8List _i64le(int value) {
    BigInt v = BigInt.from(value);
    final two64 = BigInt.one << 64;
    if (v.isNegative) {
      v = two64 + v;
    }
    final out = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      out[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return out;
  }
}

class RoleInputArgs {
  RoleInputArgs({
    required this.owner,
    required this.roleIndex,
    required this.monthlyLimit,
  });
  final String owner;
  final int roleIndex; // 0: BoardMember, 1: FinanceOfficer, 2: Auditor
  final int monthlyLimit;
}

class ProgramPda {
  const ProgramPda(this.pubkey, this.bump);
  final Ed25519HDPublicKey pubkey;
  final int bump;
}

class InitMultisigResult {
  const InitMultisigResult({
    required this.txSignature,
    required this.multisigAddress,
    required this.vaultAddress,
  });
  final String txSignature;
  final String multisigAddress;
  final String vaultAddress;
}

extension WalletServiceKeypair on WalletService {
  Future<Ed25519HDKeyPair> loadKeypair() async {
    final mnemonic = await readMnemonic();
    return Ed25519HDKeyPair.fromMnemonic(mnemonic);
  }
}
