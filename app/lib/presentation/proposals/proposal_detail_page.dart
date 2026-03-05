import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/proposal.dart';

import '../../services/multisig_providers.dart';
import '../../services/proposal_providers.dart';
import '../../services/solana_providers.dart';
import '../../services/wallet_controller.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/success_animation.dart';

class ProposalDetailPage extends ConsumerStatefulWidget {
  const ProposalDetailPage({required this.proposalId, super.key});
  final String proposalId;

  @override
  ConsumerState<ProposalDetailPage> createState() => _ProposalDetailPageState();
}

class _ProposalDetailPageState extends ConsumerState<ProposalDetailPage> {
  bool _approving = false;
  bool _executing = false;

  Future<void> _approve(Proposal proposal) async {
    setState(() => _approving = true);
    HapticFeedback.mediumImpact();
    try {
      final txSig = await ref
          .read(proposalServiceProvider)
          .approve(
            proposalId: int.parse(proposal.id),
            wallet: ref.read(walletServiceProvider),
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      HapticFeedback.heavyImpact();

      // Show success animation
      await SuccessAnimationDialog.show(
        context: context,
        message: 'Approved Successfully',
        subtitle: 'Your approval has been recorded on-chain',
        txSignature: txSig,
      );

      if (!mounted) return;
      // Re-fetch state
      ref.invalidate(proposalsProvider);
      ref.invalidate(proposalByIdProvider(widget.proposalId));
      ref.invalidate(multisigInfoProvider);
    } on TimeoutException {
      if (!mounted) return;
      await TransactionErrorDialog.show(
        context: context,
        errorMessage:
            'Request timed out. Check your network and RPC connection.',
      );
    } catch (e) {
      if (!mounted) return;
      await TransactionErrorDialog.show(context: context, errorMessage: '$e');
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _execute(Proposal proposal) async {
    setState(() => _executing = true);
    HapticFeedback.mediumImpact();
    try {
      String txSig;
      if (proposal.isGovernance) {
        txSig = await ref
            .read(proposalServiceProvider)
            .executeGovernance(
              proposalId: int.parse(proposal.id),
              action: proposal.action,
              wallet: ref.read(walletServiceProvider),
            )
            .timeout(const Duration(seconds: 30));
      } else {
        txSig = await ref
            .read(proposalServiceProvider)
            .execute(
              proposalId: int.parse(proposal.id),
              destination: proposal.destination,
              wallet: ref.read(walletServiceProvider),
            )
            .timeout(const Duration(seconds: 30));
      }
      if (!mounted) return;
      HapticFeedback.heavyImpact();

      // Show success animation (plays for ~3 seconds)
      await SuccessAnimationDialog.show(
        context: context,
        message: 'Proposal Executed Successfully',
        subtitle: proposal.isGovernance
            ? '${proposal.action.label} has been applied'
            : 'Transfer has been processed',
        txSignature: txSig,
      );

      if (!mounted) return;

      // Re-fetch ALL state after execution completes
      ref.invalidate(proposalsProvider);
      ref.invalidate(proposalByIdProvider(widget.proposalId));
      ref.invalidate(balanceProvider);
      ref.invalidate(vaultBalanceProvider);
      ref.invalidate(multisigInfoProvider);

      // Navigate back to main/home after state refresh
      if (mounted) {
        context.go('/main');
      }
    } on TimeoutException {
      if (!mounted) return;
      await TransactionErrorDialog.show(
        context: context,
        errorMessage:
            'Request timed out. Check your network and RPC connection.',
      );
    } catch (e) {
      if (!mounted) return;
      await TransactionErrorDialog.show(context: context, errorMessage: '$e');
    } finally {
      if (mounted) setState(() => _executing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposalState = ref.watch(proposalByIdProvider(widget.proposalId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: proposalState.when(
        loading: () => const _DetailSkeleton(),
        error: (err, _) => _ErrorState(
          onRetry: () {
            ref.invalidate(proposalByIdProvider(widget.proposalId));
          },
        ),
        data: (proposal) {
          if (proposal == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: AppColors.textTertiary.withAlpha(120),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Proposal not found',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }
          return _buildContent(context, proposal);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Proposal proposal) {
    final amountSol = proposal.amountLamports / lamportsPerSol;
    final executed = proposal.executed;
    final isGovernance = proposal.isGovernance;
    final threshold = 2;
    final expiresDate = DateTime.fromMillisecondsSinceEpoch(
      proposal.expiresAt * 1000,
    );
    final isExpired = expiresDate.isBefore(DateTime.now());
    final dateFormat = DateFormat('MMM d, yyyy · HH:mm');

    return Stack(
      children: [
        // ── Scrollable Content ─────────────────────────────────────────
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: _BackButton(),
              title: Text(
                'Proposal #${proposal.id}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _statusBadge(executed, isGovernance, isExpired),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Amount Card ────────────────────────────────────
                    _AmountCard(
                      amountSol: amountSol,
                      lamports: proposal.amountLamports,
                    ),
                    const SizedBox(height: 16),

                    // ── Approval Progress ──────────────────────────────
                    _ApprovalCard(
                      approvals: proposal.approvals,
                      threshold: threshold,
                    ),
                    const SizedBox(height: 16),

                    // ── Details ────────────────────────────────────────
                    _DetailsCard(
                      proposal: proposal,
                      dateFormat: dateFormat,
                      isExpired: isExpired,
                      isGovernance: isGovernance,
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Fixed Bottom Action Bar ────────────────────────────────────
        if (!executed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withAlpha(20),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _approving ? null : () => _approve(proposal),
                      icon: _approving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                      label: Flexible(
                        child: Text(
                          _approving ? 'Approving...' : 'Approve',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TactileButton(
                      onPressed: _executing ? null : () => _execute(proposal),
                      isLoading: _executing,
                      enabled: !_executing,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_executing)
                            Icon(
                              isGovernance
                                  ? Icons.gavel_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 18,
                            ),
                          if (!_executing) const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isGovernance ? 'Execute Gov.' : 'Execute',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _statusBadge(bool executed, bool isGovernance, bool isExpired) {
    if (executed) return StatusBadge.executed();
    if (isExpired) {
      return const StatusBadge(
        label: 'Expired',
        color: AppColors.error,
        backgroundColor: AppColors.errorBg,
        icon: Icons.timer_off_rounded,
      );
    }
    if (isGovernance) return StatusBadge.governance();
    return StatusBadge.pending();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.amountSol, required this.lamports});
  final double amountSol;
  final int lamports;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Spacing.borderRadiusXl,
        boxShadow: cardShadow,
        border: Border.all(color: AppColors.border.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(
            'Transfer Amount',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedBalance(
            balance: amountSol,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat('#,###').format(lamports)} lamports',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.approvals, required this.threshold});
  final List<String> approvals;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Text(
            'Approval Progress',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ApprovalProgressBar(current: approvals.length, total: threshold),
          if (approvals.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Signers',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            ...approvals.map(
              (addr) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.successBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _truncateAddress(addr),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: addr));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address copied')),
                        );
                      },
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _truncateAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.proposal,
    required this.dateFormat,
    required this.isExpired,
    required this.isGovernance,
  });
  final Proposal proposal;
  final DateFormat dateFormat;
  final bool isExpired;
  final bool isGovernance;

  @override
  Widget build(BuildContext context) {
    final expiresDate = DateTime.fromMillisecondsSinceEpoch(
      proposal.expiresAt * 1000,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Spacing.borderRadiusLg,
        boxShadow: cardShadow,
        border: Border.all(color: AppColors.border.withAlpha(60)),
      ),
      child: Column(
        children: [
          _DetailLine(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Destination',
            value: _truncate(proposal.destination),
            copyValue: proposal.destination,
            isMono: true,
          ),
          const _Separator(),
          _DetailLine(
            icon: Icons.person_outline_rounded,
            label: 'Proposer',
            value: _truncate(proposal.proposer),
            copyValue: proposal.proposer,
            isMono: true,
          ),
          const _Separator(),
          _DetailLine(
            icon: Icons.schedule_rounded,
            label: 'Expires',
            value: isExpired ? 'Expired' : dateFormat.format(expiresDate),
            valueColor: isExpired ? AppColors.error : null,
          ),
          const _Separator(),
          _DetailLine(
            icon: Icons.tag_rounded,
            label: 'Type',
            value: isGovernance ? 'Governance' : 'Transfer',
          ),
          const _Separator(),
          _DetailLine(
            icon: Icons.fingerprint_rounded,
            label: 'Account',
            value: _truncate(proposal.accountPubkey),
            copyValue: proposal.accountPubkey,
            isMono: true,
          ),
        ],
      ),
    );
  }

  String _truncate(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
    this.copyValue,
    this.isMono = false,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? copyValue;
  final bool isMono;
  final Color? valueColor;

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
                style: isMono
                    ? GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: valueColor ?? AppColors.textPrimary,
                      )
                    : GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: valueColor ?? AppColors.textPrimary,
                      ),
              ),
            ],
          ),
        ),
        if (copyValue != null)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: copyValue!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Icon(
              Icons.copy_rounded,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const SkeletonBox(width: 180, height: 20),
            const SizedBox(height: 24),
            SkeletonCard(height: 120),
            const SizedBox(height: 16),
            SkeletonCard(height: 100),
            const SizedBox(height: 16),
            SkeletonCard(height: 180),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load proposal',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
