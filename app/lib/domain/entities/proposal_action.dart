import 'dart:typed_data';

import 'package:solana/solana.dart' show Ed25519HDPublicKey;
import 'package:solana/base58.dart';

/// Mirrors the on-chain `ProposalAction` Borsh enum.
///
/// Discriminator byte mapping:
///  0 = Transfer
///  1 = UpdateThreshold { new_threshold: u8 }
///  2 = AddOwner       { new_owner: Pubkey }
///  3 = RemoveOwner    { owner: Pubkey }
///  4 = UpdateRole     { owner: Pubkey, role: u8 }
///  5 = UpdateMonthlyLimit { owner: Pubkey, new_limit: u64 }
sealed class ProposalAction {
  const ProposalAction();

  /// Whether this is a plain SOL transfer (non-governance).
  bool get isTransfer => this is TransferAction;

  /// Whether this is any governance action.
  bool get isGovernance => !isTransfer;

  /// Human-readable label for UI display.
  String get label;

  /// Borsh-serialise this action for on-chain instruction data.
  Uint8List serialize();

  /// Decode a [ProposalAction] from Borsh-serialised bytes starting at [offset].
  /// Returns the decoded action and the number of bytes consumed.
  static (ProposalAction, int) deserialize(Uint8List data, int offset) {
    final disc = data[offset];
    switch (disc) {
      case 0:
        return (const TransferAction(), 1);
      case 1:
        return (UpdateThresholdAction(newThreshold: data[offset + 1]), 2);
      case 2:
        final pk = base58encode(data.sublist(offset + 1, offset + 33));
        return (AddOwnerAction(newOwner: pk), 33);
      case 3:
        final pk = base58encode(data.sublist(offset + 1, offset + 33));
        return (RemoveOwnerAction(owner: pk), 33);
      case 4:
        final pk = base58encode(data.sublist(offset + 1, offset + 33));
        final role = data[offset + 33];
        return (UpdateRoleAction(owner: pk, roleIndex: role), 34);
      case 5:
        final pk = base58encode(data.sublist(offset + 1, offset + 33));
        final limit = _readU64(data, offset + 33);
        return (UpdateMonthlyLimitAction(owner: pk, newLimit: limit), 41);
      default:
        // Unknown variant – treat as Transfer to avoid crashes.
        return (const TransferAction(), 1);
    }
  }
}

class TransferAction extends ProposalAction {
  const TransferAction();

  @override
  String get label => 'Transfer';

  @override
  Uint8List serialize() => Uint8List.fromList([0]);
}

class UpdateThresholdAction extends ProposalAction {
  const UpdateThresholdAction({required this.newThreshold});
  final int newThreshold;

  @override
  String get label => 'Update Threshold → $newThreshold';

  @override
  Uint8List serialize() => Uint8List.fromList([1, newThreshold]);
}

class AddOwnerAction extends ProposalAction {
  const AddOwnerAction({required this.newOwner});
  final String newOwner;

  @override
  String get label => 'Add Owner';

  @override
  Uint8List serialize() {
    final buf = BytesBuilder(copy: false);
    buf.addByte(2);
    buf.add(Ed25519HDPublicKey.fromBase58(newOwner).bytes);
    return buf.toBytes();
  }
}

class RemoveOwnerAction extends ProposalAction {
  const RemoveOwnerAction({required this.owner});
  final String owner;

  @override
  String get label => 'Remove Owner';

  @override
  Uint8List serialize() {
    final buf = BytesBuilder(copy: false);
    buf.addByte(3);
    buf.add(Ed25519HDPublicKey.fromBase58(owner).bytes);
    return buf.toBytes();
  }
}

class UpdateRoleAction extends ProposalAction {
  const UpdateRoleAction({required this.owner, required this.roleIndex});
  final String owner;
  final int roleIndex; // 0: BoardMember, 1: FinanceOfficer, 2: Auditor

  @override
  String get label {
    const names = ['BoardMember', 'FinanceOfficer', 'Auditor'];
    final roleName = roleIndex < names.length
        ? names[roleIndex]
        : 'Role($roleIndex)';
    return 'Update Role → $roleName';
  }

  @override
  Uint8List serialize() {
    final buf = BytesBuilder(copy: false);
    buf.addByte(4);
    buf.add(Ed25519HDPublicKey.fromBase58(owner).bytes);
    buf.addByte(roleIndex);
    return buf.toBytes();
  }
}

class UpdateMonthlyLimitAction extends ProposalAction {
  const UpdateMonthlyLimitAction({required this.owner, required this.newLimit});
  final String owner;
  final int newLimit;

  @override
  String get label => 'Update Monthly Limit';

  @override
  Uint8List serialize() {
    final buf = BytesBuilder(copy: false);
    buf.addByte(5);
    buf.add(Ed25519HDPublicKey.fromBase58(owner).bytes);
    buf.add(_u64le(newLimit));
    return buf.toBytes();
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

Uint8List _u64le(int value) {
  var v = BigInt.from(value);
  final out = Uint8List(8);
  for (int i = 0; i < 8; i++) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}

int _readU64(Uint8List data, int offset) {
  BigInt v = BigInt.zero;
  for (int i = 0; i < 8; i++) {
    v |= BigInt.from(data[offset + i]) << (8 * i);
  }
  return v.toInt();
}
