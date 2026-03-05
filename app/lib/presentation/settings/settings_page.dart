import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/config_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/proposal_action.dart';
import '../../services/multisig_providers.dart';
import '../../services/proposal_providers.dart';
import '../../services/solana_providers.dart';
import '../../services/wallet_controller.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/success_animation.dart';
import '../qr/qr_scanner_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _multisigController = TextEditingController();
  bool _dirty = false;
  bool _saving = false;
  bool _syncedOnce = false;
  bool _suppressDirty = false;

  @override
  void initState() {
    super.initState();
    _multisigController.addListener(_onFieldEdited);
  }

  @override
  void dispose() {
    _multisigController.dispose();
    super.dispose();
  }

  void _onFieldEdited() {
    if (_suppressDirty) return;
    setState(() {
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final multisig = _multisigController.text.trim();

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    await ref
        .read(appConfigProvider.notifier)
        .update(
          rpcUrl: defaultAppConfig.rpcUrl,
          programId: defaultAppConfig.programId,
          multisigAddress: multisig,
        );

    _suppressDirty = true;
    _multisigController.text = multisig;
    _dirty = false;
    _suppressDirty = false;

    ref.invalidate(solanaRpcServiceProvider);
    ref.invalidate(balanceProvider);
    ref.invalidate(proposalsProvider);
    ref.invalidate(multisigInfoProvider);
    ref.invalidate(vaultBalanceProvider);

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
    super.build(context);

    ref.listen(appConfigProvider, (prev, next) {
      if (next.hasValue && !_dirty && !_syncedOnce) {
        final config = next.valueOrNull;
        if (config != null) {
          _suppressDirty = true;
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
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // ── Header ────────────────────────────────────────────────
            Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // ── Governance Actions ────────────────────────────────────
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
              onTap: () => _openAddMemberSheet(context),
            ),
            const SizedBox(height: 10),
            _GovernanceActionCard(
              icon: Icons.tune_rounded,
              title: 'Adjust Threshold',
              subtitle: 'Update the number of approvals required',
              color: AppColors.info,
              onTap: () => _openThresholdSheet(context),
            ),
            const SizedBox(height: 10),
            _GovernanceActionCard(
              icon: Icons.shield_outlined,
              title: 'Update Limits',
              subtitle: 'Set monthly withdrawal limits per role',
              color: AppColors.warning,
              onTap: () => _openMonthlyLimitSheet(context),
            ),
            const SizedBox(height: 28),

            // ── Environment ──────────────────────────────────────────
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
              'Configure your multisig wallet address',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Read-only defaults ──
                  _DefaultInfoRow(
                    icon: Icons.cloud_outlined,
                    label: 'RPC URL',
                    value: defaultAppConfig.rpcUrl,
                  ),
                  const SizedBox(height: 10),
                  _DefaultInfoRow(
                    icon: Icons.code_rounded,
                    label: 'Program ID',
                    value: defaultAppConfig.programId,
                  ),
                  const Divider(height: 24),
                  // ── Editable multisig address ──
                  TextField(
                    controller: _multisigController,
                    enabled: !isLoading,
                    style: GoogleFonts.jetBrainsMono(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Multisig Address',
                      hintText: 'Base58 multisig account',
                      prefixIcon: const Icon(
                        Icons.account_balance_outlined,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Scan QR Code',
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 20,
                          color: AppColors.brand,
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final scanned = await Navigator.of(context)
                                    .push<String>(
                                      MaterialPageRoute(
                                        builder: (_) => const QrScannerPage(),
                                      ),
                                    );
                                if (scanned != null &&
                                    scanned.isNotEmpty &&
                                    mounted) {
                                  _multisigController.text = scanned;
                                }
                              },
                      ),
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

            const SizedBox(height: 32),

            // ── Danger Zone ──────────────────────────────────────────
            Text(
              'Danger Zone',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 12),
            _DangerAction(
              icon: Icons.restart_alt_rounded,
              title: 'Reset Configuration',
              subtitle: 'Reset RPC and program ID (keeps multisig empty)',
              onTap: () async {
                await ref
                    .read(appConfigProvider.notifier)
                    .update(
                      rpcUrl: defaultAppConfig.rpcUrl,
                      programId: defaultAppConfig.programId,
                      multisigAddress: '',
                    );
                _syncedOnce = false;
                ref.invalidate(appConfigProvider);
                _showSnack('Configuration reset to defaults');
              },
            ),
            const SizedBox(height: 10),
            _DangerAction(
              icon: Icons.delete_forever_rounded,
              title: 'Delete Wallet',
              subtitle: 'Remove local keypair and all cached data',
              onTap: () => _showDeleteWalletDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteWalletDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Wallet',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'This will remove your wallet from this device. '
          'Your on-chain multisig will NOT be deleted.\n\n'
          'Are you sure?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(walletControllerProvider.notifier).clear();
              await ref
                  .read(appConfigProvider.notifier)
                  .update(multisigAddress: '');
              if (!context.mounted) return;
              context.go('/');
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Governance sheets ──────────────────────────────────────────────────

  void _openAddMemberSheet(BuildContext context) {
    final multisig =
        (ref.read(appConfigProvider).valueOrNull ?? defaultAppConfig)
            .multisigAddress;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GovSheet(
        title: 'Add Member',
        icon: Icons.group_add_rounded,
        fields: const [
          _Field(
            label: 'New owner public key',
            hint: 'Base58 address',
            icon: Icons.person_add_rounded,
          ),
        ],
        onSubmit: (values) {
          if (values[0].isEmpty) {
            _showSnack('Enter the new owner address');
            return;
          }
          _submitGov(AddOwnerAction(newOwner: values[0]), multisig, 0);
        },
      ),
    );
  }

  void _openThresholdSheet(BuildContext context) {
    final multisig =
        (ref.read(appConfigProvider).valueOrNull ?? defaultAppConfig)
            .multisigAddress;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GovSheet(
        title: 'Adjust Threshold',
        icon: Icons.tune_rounded,
        fields: const [
          _Field(
            label: 'New approval threshold',
            hint: 'e.g. 2',
            icon: Icons.how_to_vote_rounded,
            isNumber: true,
          ),
        ],
        onSubmit: (values) {
          final threshold = int.tryParse(values[0]);
          if (threshold == null || threshold < 1) {
            _showSnack('Enter a valid threshold (>= 1)');
            return;
          }
          _submitGov(
            UpdateThresholdAction(newThreshold: threshold),
            multisig,
            0,
          );
        },
      ),
    );
  }

  void _openMonthlyLimitSheet(BuildContext context) {
    final multisig =
        (ref.read(appConfigProvider).valueOrNull ?? defaultAppConfig)
            .multisigAddress;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GovSheet(
        title: 'Update Monthly Limit',
        icon: Icons.shield_outlined,
        fields: const [
          _Field(
            label: 'Owner address',
            hint: 'Base58 public key of the member',
            icon: Icons.person_outline_rounded,
          ),
          _Field(
            label: 'New monthly limit (SOL)',
            hint: 'e.g. 5 (= 5 SOL)',
            icon: Icons.money_rounded,
            isNumber: true,
          ),
        ],
        onSubmit: (values) {
          if (values[0].isEmpty) {
            _showSnack('Enter the owner address');
            return;
          }
          final solValue = double.tryParse(values[1]);
          if (solValue == null || solValue < 0) {
            _showSnack('Enter a valid limit in SOL');
            return;
          }
          final limitLamports = (solValue * lamportsPerSol).round();
          _submitGov(
            UpdateMonthlyLimitAction(owner: values[0], newLimit: limitLamports),
            multisig,
            0,
          );
        },
      ),
    );
  }

  Future<void> _submitGov(
    ProposalAction action,
    String destination,
    double amountSol,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    if (destination.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Multisig address required')),
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

    // Pop the bottom sheet (local navigator, not root).
    Navigator.of(context).pop();

    if (!mounted) return;

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
    final expiresAt = nowSec + (24 * 3600);

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
      loadingEntry.remove();
    }

    if (!mounted) return;

    // Always refresh providers.
    ref.invalidate(proposalsProvider);
    ref.invalidate(balanceProvider);
    ref.invalidate(vaultBalanceProvider);
    ref.invalidate(multisigInfoProvider);

    if (error == null) {
      HapticFeedback.heavyImpact();
      await SuccessAnimationDialog.show(
        context: context,
        message: '${action.label} Proposal Submitted',
        subtitle: 'Governance proposal created successfully',
      );
    } else {
      await TransactionErrorDialog.show(context: context, errorMessage: error);
    }
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

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

class _DefaultInfoRow extends StatelessWidget {
  const _DefaultInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DangerAction extends StatelessWidget {
  const _DangerAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Spacing.borderRadiusLg,
        border: Border.all(color: AppColors.error.withAlpha(40)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: Spacing.borderRadiusLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: Spacing.borderRadiusLg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: Spacing.borderRadiusMd,
                  ),
                  child: Icon(icon, color: AppColors.error, size: 22),
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
                          color: AppColors.error,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Governance form sheet ────────────────────────────────────────────────────

class _Field {
  const _Field({
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

class _GovSheet extends StatefulWidget {
  const _GovSheet({
    required this.title,
    required this.icon,
    required this.fields,
    required this.onSubmit,
  });

  final String title;
  final IconData icon;
  final List<_Field> fields;
  final void Function(List<String> values) onSubmit;

  @override
  State<_GovSheet> createState() => _GovSheetState();
}

class _GovSheetState extends State<_GovSheet> {
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
