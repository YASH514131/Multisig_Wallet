import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/entities/proposal_action.dart';
import '../../services/multisig_providers.dart';
import '../../services/proposal_providers.dart';
import '../../services/solana_providers.dart';
import '../../services/wallet_controller.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/success_animation.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _heroController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _heroSlide = Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _heroController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heroController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  Future<void> _refreshAll() async {
    HapticFeedback.lightImpact();
    final wallet = ref.read(walletControllerProvider).valueOrNull;
    if (wallet == null) return;
    ref.invalidate(balanceProvider);
    ref.invalidate(proposalsProvider);
    await ref.read(balanceProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletControllerProvider);
    final address = walletState.valueOrNull?.address ?? '';
    final balanceState = ref.watch(balanceProvider);
    final proposalsState = ref.watch(proposalsProvider);

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
              // ── Top Bar ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'T',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
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
                              'True Wallet',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (address.isNotEmpty)
                              AddressChip(address: address, maxLength: 16),
                          ],
                        ),
                      ),
                      _IconBtn(
                        icon: Icons.refresh_rounded,
                        onTap: _refreshAll,
                        tooltip: 'Refresh',
                      ),
                      const SizedBox(width: 4),
                      _IconBtn(
                        icon: Icons.settings_rounded,
                        onTap: () => context.go('/main/governance'),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),

              // ── Hero Vault Card ──────────────────────────────────────
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _heroSlide,
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _HeroVaultCard(balanceState: balanceState),
                    ),
                  ),
                ),
              ),

              // ── Quick Actions ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      QuickActionButton(
                        icon: Icons.arrow_upward_rounded,
                        label: 'Send',
                        onTap: () => context.go('/main/send'),
                        color: AppColors.brand,
                      ),
                      QuickActionButton(
                        icon: Icons.arrow_downward_rounded,
                        label: 'Receive',
                        onTap: () {
                          if (address.isEmpty) return;
                          HapticFeedback.lightImpact();
                          context.go('/main/receive');
                        },
                        color: AppColors.success,
                      ),
                      QuickActionButton(
                        icon: Icons.add_rounded,
                        label: 'Propose',
                        onTap: _openCreateProposalSheet,
                        color: AppColors.info,
                      ),
                      QuickActionButton(
                        icon: Icons.rocket_launch_rounded,
                        label: 'Initialize',
                        onTap: () => context.go('/main/init-multisig'),
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stats Row ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _StatsRow(proposalsState: proposalsState),
                ),
              ),

              // ── Section Header ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'Recent Proposals',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      proposalsState.whenOrNull(
                            data: (items) => Text(
                              '${items.length} total',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ) ??
                          const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),

              // ── Proposal List ────────────────────────────────────────
              proposalsState.when(
                data: (items) {
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 40,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 48,
                              color: AppColors.textTertiary.withAlpha(120),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No proposals yet',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create your first proposal to get started',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final p = items[index];
                        return _ProposalCard(
                          proposal: p,
                          onTap: () => context.go('/main/proposal/${p.id}'),
                          index: index,
                        );
                      },
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, __) => const SkeletonCard(height: 88),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: GlassCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Failed to load proposals',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _refreshAll,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Bottom spacing for FAB ───────────────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: _AnimatedFab(onPressed: _openCreateProposalSheet),
    );
  }w

  // ── Create Proposal Bottom Sheet ───────────────────────────────────────
  void _openCreateProposalSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateProposalSheet(
        onSubmit: (dest, amount, expires, action) {
          _submitProposal(dest, amount, expires, action);
        },
      ),
    );
  }

  Future<void> _submitProposal(
    String dest,
    String amountStr,
    String expiresStr,
    ProposalAction action,
  ) async {
    // Use the page-level context (not bottom sheet) for scaffold messenger.
    final messenger = ScaffoldMessenger.of(context);

    if (dest.isEmpty || amountStr.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Destination and amount are required')),
      );
      return;
    }
    final amountSol = double.tryParse(amountStr);
    if (amountSol == null || amountSol <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final expiresHours = int.tryParse(expiresStr) ?? 24;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = nowSec + (expiresHours * 3600);
    final proposalId = DateTime.now().millisecondsSinceEpoch;

    final wallet = ref.read(walletControllerProvider).valueOrNull;
    if (wallet == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Load or create a wallet first')),
      );
      return;
    }

    // Pop the bottom sheet (it was pushed on the local navigator by showModalBottomSheet).
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

    String? error;
    try {
      final svc = ref.read(proposalServiceProvider);
      await svc
          .create(
            destination: dest,
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
      error = '$e';
    } finally {
      // Safe removal – only removes this overlay, never pops Navigator routes.
      loadingEntry.remove();
    }

    if (!mounted) return;

    // Always refresh providers – the tx may have landed even on timeout.
    ref.invalidate(proposalsProvider);
    ref.invalidate(balanceProvider);
    ref.invalidate(vaultBalanceProvider);
    ref.invalidate(multisigInfoProvider);

    if (error == null) {
      HapticFeedback.heavyImpact();
      await SuccessAnimationDialog.show(
        context: context,
        message: 'Proposal Submitted',
        subtitle: action is TransferAction
            ? 'Transfer proposal created successfully'
            : '${action.label} proposal created',
      );
    } else {
      await TransactionErrorDialog.show(context: context, errorMessage: error);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
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
      ),
    );
  }
}

/// Gradient hero card showing vault balance.
class _HeroVaultCard extends ConsumerWidget {
  const _HeroVaultCard({required this.balanceState});

  final AsyncValue<double> balanceState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: Spacing.borderRadiusXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withAlpha(50),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(Spacing.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Vault · Devnet',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: Colors.white.withAlpha(150),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Total Balance',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha(180),
            ),
          ),
          const SizedBox(height: 4),
          balanceState.when(
            data: (balance) => AnimatedBalance(
              balance: balance,
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            loading: () => const SkeletonBox(width: 180, height: 36),
            error: (_, __) => Text(
              'Unavailable',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white.withAlpha(130),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: Colors.white.withAlpha(180),
                ),
                const SizedBox(width: 6),
                Text(
                  'Multisig · 2-of-5 threshold',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stats row with pending, executed counts.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.proposalsState});

  final AsyncValue<List<Proposal>> proposalsState;

  @override
  Widget build(BuildContext context) {
    return proposalsState.when(
      data: (items) {
        final pending = items.where((p) => !p.executed).length;
        final executed = items.where((p) => p.executed).length;
        final governance = items.where((p) => p.isGovernance).length;
        return Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.schedule_rounded,
                label: 'Pending',
                value: '$pending',
                color: AppColors.pending,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                icon: Icons.check_circle_rounded,
                label: 'Executed',
                value: '$executed',
                color: AppColors.executed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                icon: Icons.gavel_rounded,
                label: 'Governance',
                value: '$governance',
                color: AppColors.governance,
              ),
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          const Expanded(child: SkeletonCard(height: 84)),
          const SizedBox(width: 10),
          const Expanded(child: SkeletonCard(height: 84)),
          const SizedBox(width: 10),
          const Expanded(child: SkeletonCard(height: 84)),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Spacing.borderRadiusMd,
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual proposal card with status badge and stagger animation.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onTap,
    required this.index,
  });

  final Proposal proposal;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = proposal;
    final amountSol = p.amountLamports / lamportsPerSol;

    final StatusBadge badge;
    final Color accentColor;
    final IconData statusIcon;

    if (p.executed) {
      badge = StatusBadge.executed();
      accentColor = AppColors.executed;
      statusIcon = Icons.check_circle_rounded;
    } else if (p.isGovernance) {
      badge = StatusBadge.governance();
      accentColor = AppColors.governance;
      statusIcon = Icons.gavel_rounded;
    } else {
      badge = StatusBadge.pending();
      accentColor = AppColors.pending;
      statusIcon = Icons.schedule_rounded;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Material(
        color: AppColors.surface,
        borderRadius: Spacing.borderRadiusLg,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: Spacing.borderRadiusLg,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: Spacing.borderRadiusLg,
              border: Border.all(color: AppColors.border.withAlpha(60)),
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
                  child: Icon(statusIcon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${amountSol.toStringAsFixed(3)} SOL',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: badge),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _truncateAddress(p.destination),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
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
      ),
    );
  }

  String _truncateAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';
  }
}

/// Bottom sheet content with its own lifecycle for safe controller disposal.
class _CreateProposalSheet extends StatefulWidget {
  const _CreateProposalSheet({required this.onSubmit});
  final void Function(
    String dest,
    String amount,
    String expires,
    ProposalAction action,
  )
  onSubmit;

  @override
  State<_CreateProposalSheet> createState() => _CreateProposalSheetState();
}

class _CreateProposalSheetState extends State<_CreateProposalSheet> {
  late final TextEditingController _destinationCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _expiresCtrl;
  bool _isGovernance = false;

  @override
  void initState() {
    super.initState();
    _destinationCtrl = TextEditingController();
    _amountCtrl = TextEditingController();
    _expiresCtrl = TextEditingController(text: '24');
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _amountCtrl.dispose();
    _expiresCtrl.dispose();
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
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.brand,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'New Proposal',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _destinationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination address',
                    hintText: 'Base58 public key',
                    prefixIcon: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (SOL)',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.toll_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _expiresCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Expires in (hours)',
                    hintText: '24',
                    prefixIcon: Icon(Icons.schedule_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Governance proposal',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'For owner/threshold/limit changes',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  value: _isGovernance,
                  onChanged: (v) => setState(() => _isGovernance = v),
                ),
                const SizedBox(height: 16),
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
                          // Build the ProposalAction from the UI toggle.
                          // For a simple transfer vs. governance toggle, we
                          // default governance to UpdateThreshold(0) as a
                          // placeholder; a full governance UI would let the
                          // user pick the exact action and params.
                          final ProposalAction action = _isGovernance
                              ? const UpdateThresholdAction(newThreshold: 0)
                              : const TransferAction();
                          widget.onSubmit(
                            _destinationCtrl.text.trim(),
                            _amountCtrl.text.trim(),
                            _expiresCtrl.text.trim(),
                            action,
                          );
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Submit'),
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

/// Animated FAB that scales in on first render.
class _AnimatedFab extends StatefulWidget {
  const _AnimatedFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
      child: FloatingActionButton.extended(
        onPressed: widget.onPressed,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Proposal'),
      ),
    );
  }
}
