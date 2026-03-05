import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/config/config_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/proposal.dart';
import '../../services/multisig_providers.dart';
import '../../services/proposal_providers.dart';
import '../../services/solana_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class DashboardAnalyticsPage extends ConsumerStatefulWidget {
  const DashboardAnalyticsPage({super.key});

  @override
  ConsumerState<DashboardAnalyticsPage> createState() =>
      _DashboardAnalyticsPageState();
}

class _DashboardAnalyticsPageState extends ConsumerState<DashboardAnalyticsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _refreshAll() async {
    HapticFeedback.lightImpact();
    ref.invalidate(multisigInfoProvider);
    ref.invalidate(vaultBalanceProvider);
    ref.invalidate(proposalsProvider);
    ref.invalidate(balanceProvider);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final config = ref.watch(appConfigProvider).valueOrNull ?? defaultAppConfig;
    final multisigInfo = ref.watch(multisigInfoProvider);
    final proposalsState = ref.watch(proposalsProvider);
    final hasMultisig = config.multisigAddress.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: AppColors.brand,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Header ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        'Dashboard',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      _IconBtn(icon: Icons.refresh_rounded, onTap: _refreshAll),
                    ],
                  ),
                ),
              ),

              if (!hasMultisig)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.dashboard_customize_rounded,
                          size: 64,
                          color: AppColors.textTertiary.withAlpha(100),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Multisig Configured',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure a multisig in Settings first',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                multisigInfo.when(
                  data: (info) {
                    if (info == null) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Loading multisig data...',
                                style: GoogleFonts.inter(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SliverToBoxAdapter(
                      child: _DashboardContent(
                        info: info,
                        proposalsState: proposalsState,
                        config: config,
                      ),
                    );
                  },
                  loading: () =>
                      const SliverToBoxAdapter(child: _DashboardSkeleton()),
                  error: (err, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load dashboard',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$err',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _refreshAll,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.info,
    required this.proposalsState,
    required this.config,
  });

  final MultisigInfo info;
  final AsyncValue<List<Proposal>> proposalsState;
  final dynamic config;

  @override
  Widget build(BuildContext context) {
    final pending =
        proposalsState.valueOrNull?.where((p) => !p.executed).length ?? 0;
    final executed =
        proposalsState.valueOrNull?.where((p) => p.executed).length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Vault Balance Card (large gradient) ─────────────────────
          _VaultBalanceCard(
            balance: info.vaultBalance,
            vault: info.vaultAddress,
          ),
          const SizedBox(height: 16),

          // ── Addresses ──────────────────────────────────────────────
          _AddressCard(
            label: 'Multisig Address',
            icon: Icons.account_balance_outlined,
            address: info.address,
          ),
          const SizedBox(height: 10),
          _AddressCard(
            label: 'Vault Address (PDA)',
            icon: Icons.lock_outline_rounded,
            address: info.vaultAddress,
          ),
          const SizedBox(height: 16),

          // ── Stats Grid (Threshold + Participants) ──────────────────
          Row(
            children: [
              Expanded(
                child: _StatSquare(
                  icon: Icons.how_to_vote_rounded,
                  label: 'Threshold',
                  value: '${info.threshold}',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatSquare(
                  icon: Icons.group_rounded,
                  label: 'Participants',
                  value: '${info.owners.length}',
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatSquare(
                  icon: Icons.schedule_rounded,
                  label: 'Pending',
                  value: '$pending',
                  color: AppColors.pending,
                  onTap: () => _showFilteredProposals(
                    context,
                    'Pending Proposals',
                    proposalsState.valueOrNull
                            ?.where((p) => !p.executed)
                            .toList() ??
                        [],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatSquare(
                  icon: Icons.check_circle_rounded,
                  label: 'Executed',
                  value: '$executed',
                  color: AppColors.executed,
                  onTap: () => _showFilteredProposals(
                    context,
                    'Executed Proposals',
                    proposalsState.valueOrNull
                            ?.where((p) => p.executed)
                            .toList() ??
                        [],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Owners Grid ────────────────────────────────────────────
          Text(
            'Owners',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ...info.owners.asMap().entries.map((entry) {
            final index = entry.key;
            final owner = entry.value;
            final role = info.roleMapping
                .where((r) => r.owner == owner)
                .firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OwnerCard(index: index, owner: owner, role: role),
            );
          }),
        ],
      ),
    );
  }

  void _showFilteredProposals(
    BuildContext context,
    String title,
    List<Proposal> proposals,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _FilteredProposalsSheet(title: title, proposals: proposals),
    );
  }
}

class _VaultBalanceCard extends StatelessWidget {
  const _VaultBalanceCard({required this.balance, required this.vault});
  final double balance;
  final String vault;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
        ),
        borderRadius: Spacing.borderRadiusXl,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withAlpha(50),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 20,
                color: Colors.white.withAlpha(200),
              ),
              const SizedBox(width: 8),
              Text(
                'Vault Balance',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBalance(
            balance: balance,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${NumberFormat('#,###').format((balance * lamportsPerSol).round())} lamports',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _truncate(vault),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: Colors.white.withAlpha(180),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncate(String addr) {
    if (addr.length <= 20) return addr;
    return '${addr.substring(0, 8)}...${addr.substring(addr.length - 8)}';
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.label,
    required this.icon,
    required this.address,
  });
  final String label;
  final IconData icon;
  final String address;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 12),
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
                  _truncate(address),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Address copied')));
            },
            child: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _truncate(String addr) {
    if (addr.length <= 20) return addr;
    return '${addr.substring(0, 8)}...${addr.substring(addr.length - 8)}';
  }
}

class _StatSquare extends StatelessWidget {
  const _StatSquare({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: Spacing.borderRadiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: Spacing.borderRadiusLg,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: Spacing.borderRadiusLg,
            boxShadow: cardShadow,
            border: Border.all(color: AppColors.border.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerCard extends StatefulWidget {
  const _OwnerCard({required this.index, required this.owner, this.role});

  final int index;
  final String owner;
  final OwnerRole? role;

  @override
  State<_OwnerCard> createState() => _OwnerCardState();
}

class _OwnerCardState extends State<_OwnerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _ownerColor(widget.index).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ownerColor(widget.index),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _truncate(widget.owner),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (role != null) ...[
                        Text(
                          role.roleName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          'Limit: ${(role.monthlyLimit / lamportsPerSol).toStringAsFixed(2)} SOL',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Full Address',
                value: widget.owner,
                mono: true,
              ),
              if (role != null) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Monthly Limit',
                  value:
                      '${(role.monthlyLimit / lamportsPerSol).toStringAsFixed(4)} SOL',
                ),
                const SizedBox(height: 8),
                _DetailRow(label: 'Role', value: role.roleName),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.owner));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Copy Address',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _ownerColor(int index) {
    const colors = [
      AppColors.brand,
      AppColors.success,
      AppColors.info,
      AppColors.warning,
      AppColors.error,
      Color(0xFF00B894),
      Color(0xFFE17055),
      Color(0xFF0984E3),
    ];
    return colors[index % colors.length];
  }

  String _truncate(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: mono
                ? GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  )
                : GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
          ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SkeletonCard(height: 84),
          const SizedBox(height: 16),
          const SkeletonCard(height: 84),
          const SizedBox(height: 10),
          const SkeletonCard(height: 84),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: SkeletonCard(height: 110)),
              SizedBox(width: 12),
              Expanded(child: SkeletonCard(height: 110)),
            ],
          ),
          const SizedBox(height: 24),
          const SkeletonCard(height: 84),
          const SizedBox(height: 10),
          const SkeletonCard(height: 84),
        ],
      ),
    );
  }
}

/// Bottom sheet that shows a filtered list of proposals.
class _FilteredProposalsSheet extends StatelessWidget {
  const _FilteredProposalsSheet({required this.title, required this.proposals});

  final String title;
  final List<Proposal> proposals;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spacing.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${proposals.length}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (proposals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: AppColors.textTertiary.withAlpha(120),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No proposals found',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  shrinkWrap: true,
                  itemCount: proposals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = proposals[index];
                    final amountSol = p.amountLamports / lamportsPerSol;

                    final Color accentColor;
                    final IconData statusIcon;
                    final String statusText;

                    if (p.executed) {
                      accentColor = AppColors.executed;
                      statusIcon = Icons.check_circle_rounded;
                      statusText = 'Executed';
                    } else if (p.isGovernance) {
                      accentColor = AppColors.governance;
                      statusIcon = Icons.gavel_rounded;
                      statusText = 'Governance';
                    } else {
                      accentColor = AppColors.pending;
                      statusIcon = Icons.schedule_rounded;
                      statusText = 'Pending';
                    }

                    return Material(
                      color: AppColors.surface,
                      borderRadius: Spacing.borderRadiusLg,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/main/proposal/${p.id}');
                        },
                        borderRadius: Spacing.borderRadiusLg,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: Spacing.borderRadiusLg,
                            border: Border.all(
                              color: AppColors.border.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: accentColor.withAlpha(20),
                                  borderRadius: Spacing.borderRadiusMd,
                                ),
                                child: Icon(
                                  statusIcon,
                                  color: accentColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.isGovernance
                                          ? p.action.label
                                          : '${amountSol.toStringAsFixed(3)} SOL',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _truncateAddr(p.destination),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 12,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: accentColor.withAlpha(20),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: accentColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textTertiary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _truncateAddr(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';
  }
}
