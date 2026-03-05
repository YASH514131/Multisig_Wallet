import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/config/config_controller.dart';
import '../../domain/entities/proposal_action.dart';
import '../../services/multisig_providers.dart';
import '../../services/proposal_providers.dart';
import '../../services/solana_providers.dart';
import '../../services/wallet_controller.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/success_animation.dart';

class GovernancePage extends ConsumerStatefulWidget {
  const GovernancePage({super.key});

  @override
  ConsumerState<GovernancePage> createState() => _GovernancePageState();
}

class _GovernancePageState extends ConsumerState<GovernancePage> {
  final TextEditingController _rpcController = TextEditingController();
  final TextEditingController _programIdController = TextEditingController();
  final TextEditingController _multisigController = TextEditingController();
  bool _dirty = false;
  bool _saving = false;
  bool _syncedOnce = false;
  bool _suppressDirty = false;

  @override
  void initState() {
    super.initState();
    _rpcController.addListener(_onFieldEdited);
    _programIdController.addListener(_onFieldEdited);
    _multisigController.addListener(_onFieldEdited);
  }

  @override
  void dispose() {
    _rpcController.dispose();
    _programIdController.dispose();
    _multisigController.dispose();
    super.dispose();
  }

  void _onFieldEdited() {
    if (_suppressDirty) return;
    setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final rpc = _rpcController.text.trim();
    final program = _programIdController.text.trim();
    final multisig = _multisigController.text.trim();

    if (rpc.isEmpty || !rpc.startsWith('http')) {
      _showSnack('Enter a valid RPC URL');
      return;
    }
    if (program.isEmpty) {
      _showSnack('Program ID is required');
      return;
    }
    if (multisig.isEmpty) {
      _showSnack('Multisig address is required');
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    await ref
        .read(appConfigProvider.notifier)
        .update(rpcUrl: rpc, programId: program, multisigAddress: multisig);

    _suppressDirty = true;
    _rpcController.text = rpc;
    _programIdController.text = program;
    _multisigController.text = multisig;
    _dirty = false;
    _suppressDirty = false;

    ref.invalidate(solanaRpcServiceProvider);
    ref.invalidate(balanceProvider);
    ref.invalidate(proposalsProvider);

    setState(() {
      _dirty = false;
      _saving = false;
    });

    if (!mounted) return;
    HapticFeedback.heavyImpact();
    _showSnack('Settings saved');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appConfigProvider, (prev, next) {
      if (next.hasValue && !_dirty && !_syncedOnce) {
        final config = next.valueOrNull;
        if (config != null) {
          _suppressDirty = true;
          _rpcController.text = config.rpcUrl;
          _programIdController.text = config.programId;
          _multisigController.text = config.multisigAddress;
          _dirty = false;
          _suppressDirty = false;
          _syncedOnce = true;
        }
      }
    });

    final configState = ref.watch(appConfigProvider);
    final isLoading = configState.isLoading || _saving;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Settings & Governance',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Governance Actions ──────────────────────────────────────
          Text(
            'Governance Actions',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _GovernanceActionCard(
            icon: Icons.rocket_launch_rounded,
            title: 'Initialize Multisig',
            subtitle: 'Create a new multisig wallet on-chain',
            color: AppColors.success,
            onTap: () => context.go('/main/init-multisig'),
          ),
          const SizedBox(height: 10),
          _GovernanceActionCard(
            icon: Icons.group_add_rounded,
            title: 'Add Member',
            subtitle: 'Submit a governance proposal to add a new owner',
            color: AppColors.brand,
            onTap: () => _openAddMemberSheet(context, ref),
          ),
          const SizedBox(height: 10),
          _GovernanceActionCard(
            icon: Icons.tune_rounded,
            title: 'Adjust Threshold',
            subtitle: 'Update the number of approvals required',
            color: AppColors.info,
            onTap: () => _openThresholdSheet(context, ref),
          ),
          const SizedBox(height: 10),
          _GovernanceActionCard(
            icon: Icons.shield_outlined,
            title: 'Update Limits',
            subtitle: 'Set monthly withdrawal limits per role',
            color: AppColors.warning,
            onTap: () => _openMonthlyLimitSheet(context, ref),
          ),
          const SizedBox(height: 28),

          // ── Environment ────────────────────────────────────────────
          Text(
            'Environment',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure your Solana connection and program settings',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: Spacing.borderRadiusLg,
              boxShadow: cardShadow,
              border: Border.all(color: AppColors.border.withAlpha(60)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _rpcController,
                  enabled: !isLoading,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'RPC URL',
                    hintText: 'https://api.devnet.solana.com',
                    prefixIcon: Icon(Icons.cloud_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _programIdController,
                  enabled: !isLoading,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Program ID',
                    hintText: 'Your deployed program ID',
                    prefixIcon: Icon(Icons.code_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _multisigController,
                  enabled: !isLoading,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Multisig Address',
                    hintText: 'Base58 multisig account',
                    prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TactileButton(
            onPressed: (!isLoading && _dirty) ? _save : null,
            isLoading: _saving,
            enabled: _dirty && !isLoading,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_saving) const Icon(Icons.save_rounded, size: 18),
                if (!_saving) const SizedBox(width: 8),
                Text(
                  _saving ? 'Saving...' : 'Save Settings',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (isLoading && !_saving) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(Spacing.radiusFull),
              child: const LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.brand,
                backgroundColor: AppColors.brandLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GovernanceActionCard extends StatelessWidget {
  const _GovernanceActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Spacing.borderRadiusLg,
        boxShadow: cardShadow,
        border: Border.all(color: AppColors.border.withAlpha(60)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: Spacing.borderRadiusLg,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: Spacing.borderRadiusLg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: Spacing.borderRadiusMd,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Governance Action Bottom Sheets
// ═══════════════════════════════════════════════════════════════════════════════

/// Show bottom sheet to create an "Add Member" governance proposal.
void _openAddMemberSheet(BuildContext context, WidgetRef ref) {
  final multisig = (ref.read(appConfigProvider).valueOrNull ?? defaultAppConfig)
      .multisigAddress;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GovernanceSheet(
      title: 'Add Member',
      icon: Icons.group_add_rounded,
      fields: const [
        _FieldSpec(
          label: 'New owner public key',
          hint: 'Base58 address of the member to add',
          icon: Icons.person_add_rounded,
        ),
      ],
      onSubmit: (values) {
        if (values[0].isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter the new owner address')),
          );
          return;
        }
        _submitGovernanceProposal(
          context: context,
          ref: ref,
          action: AddOwnerAction(newOwner: values[0]),
          destination: multisig,
          amountSol: 0,
        );
      },
    ),
  );
}

/// Show bottom sheet to create an "Update Threshold" governance proposal.
void _openThresholdSheet(BuildContext context, WidgetRef ref) {
  final multisig = (ref.read(appConfigProvider).valueOrNull ?? defaultAppConfig)
      .multisigAddress;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GovernanceSheet(
      title: 'Adjust Threshold',
      icon: Icons.tune_rounded,
      fields: const [
        _FieldSpec(
          label: 'New approval threshold',
          hint: 'e.g. 2',
          icon: Icons.how_to_vote_rounded,
          isNumber: true,
        ),
      ],
      onSubmit: (values) {
        final threshold = int.tryParse(values[0]);
        if (threshold == null || threshold < 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid threshold (≥ 1)')),
          );
          return;
        }
        _submitGovernanceProposal(
          context: context,
          ref: ref,
          action: UpdateThresholdAction(newThreshold: threshold),
          destination: multisig,
          amountSol: 0,
        );
      },
    ),
  );
}

/// Show bottom sheet to create an "Update Monthly Limit" governance proposal.
void _openMonthlyLimitSheet(BuildContext context, WidgetRef ref) {
  final multisig = (ref.read(appConfigProvider).valueOrNull ?? defaultAppConfig)
      .multisigAddress;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GovernanceSheet(
      title: 'Update Monthly Limit',
      icon: Icons.shield_outlined,
      fields: const [
        _FieldSpec(
          label: 'Owner address',
          hint: 'Base58 public key of the member',
          icon: Icons.person_outline_rounded,
        ),
        _FieldSpec(
          label: 'New monthly limit (SOL)',
          hint: 'e.g. 5 (= 5 SOL)',
          icon: Icons.money_rounded,
          isNumber: true,
        ),
      ],
      onSubmit: (values) {
        if (values[0].isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter the owner address')),
          );
          return;
        }
        final solValue = double.tryParse(values[1]);
        if (solValue == null || solValue < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid limit in SOL')),
          );
          return;
        }
        final limitLamports = (solValue * lamportsPerSol).round();
        _submitGovernanceProposal(
          context: context,
          ref: ref,
          action: UpdateMonthlyLimitAction(
            owner: values[0],
            newLimit: limitLamports,
          ),
          destination: multisig,
          amountSol: 0,
        );
      },
    ),
  );
}

/// Common handler: creates a governance proposal via ProposalService.
Future<void> _submitGovernanceProposal({
  required BuildContext context,
  required WidgetRef ref,
  required ProposalAction action,
  required String destination,
  required double amountSol,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  if (destination.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Destination address is required')),
    );
    return;
  }

  final wallet = ref.read(walletControllerProvider).valueOrNull;
  if (wallet == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Load or create a wallet first')),
    );
    return;
  }

  // Pop the bottom sheet first.
  navigator.pop();

  if (!context.mounted) return;

  // Show loading overlay using OverlayEntry (never touches Navigator stack).
  final overlay = Overlay.of(context);
  final loadingEntry = OverlayEntry(
    builder: (_) => Material(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Submitting proposal...'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(loadingEntry);

  final proposalId = DateTime.now().millisecondsSinceEpoch;
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final expiresAt = nowSec + (24 * 3600); // 24 h default

  String? error;
  try {
    final svc = ref.read(proposalServiceProvider);
    await svc
        .create(
          destination: destination,
          amountLamports: (amountSol * lamportsPerSol).round(),
          expiresAt: expiresAt,
          proposalId: proposalId,
          action: action,
          wallet: ref.read(walletServiceProvider),
        )
        .timeout(const Duration(seconds: 30));
  } on TimeoutException {
    error = 'Request timed out. Check your network and RPC connection.';
  } catch (e) {
    error = 'Governance proposal failed: $e';
  } finally {
    // Safe removal – only removes this overlay, never pops Navigator routes.
    loadingEntry.remove();
  }

  if (!context.mounted) return;

  // Always refresh providers – the tx may have landed even on timeout.
  ref.invalidate(proposalsProvider);
  ref.invalidate(balanceProvider);
  ref.invalidate(vaultBalanceProvider);
  ref.invalidate(multisigInfoProvider);

  if (error == null) {
    HapticFeedback.heavyImpact();
    await SuccessAnimationDialog.show(
      context: context,
      message: '${action.label} Submitted',
      subtitle: 'Governance proposal created successfully',
    );
    // Navigate back to home tab to see the new proposal.
    if (context.mounted) context.go('/main');
  } else {
    await TransactionErrorDialog.show(context: context, errorMessage: error);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Reusable governance form bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _FieldSpec {
  const _FieldSpec({
    required this.label,
    required this.hint,
    required this.icon,
    this.isNumber = false,
  });
  final String label;
  final String hint;
  final IconData icon;
  final bool isNumber;
}

class _GovernanceSheet extends StatefulWidget {
  const _GovernanceSheet({
    required this.title,
    required this.icon,
    required this.fields,
    required this.onSubmit,
  });

  final String title;
  final IconData icon;
  final List<_FieldSpec> fields;
  final void Function(List<String> values) onSubmit;

  @override
  State<_GovernanceSheet> createState() => _GovernanceSheetState();
}

class _GovernanceSheetState extends State<_GovernanceSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.fields.length,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spacing.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.brandLight,
                        borderRadius: Spacing.borderRadiusMd,
                      ),
                      child: Icon(
                        widget.icon,
                        color: AppColors.brand,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                for (int i = 0; i < widget.fields.length; i++) ...[
                  TextField(
                    controller: _controllers[i],
                    keyboardType: widget.fields[i].isNumber
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    style: GoogleFonts.jetBrainsMono(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: widget.fields[i].label,
                      hintText: widget.fields[i].hint,
                      prefixIcon: Icon(widget.fields[i].icon, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          final values = _controllers
                              .map((c) => c.text.trim())
                              .toList();
                          widget.onSubmit(values);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.gavel_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Create Proposal',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
