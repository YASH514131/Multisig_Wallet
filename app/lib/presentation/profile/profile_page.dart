import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/config/config_controller.dart';
import '../../services/solana_providers.dart';
import '../../services/wallet_controller.dart';
import '../../shared/widgets/common_widgets.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final walletState = ref.watch(walletControllerProvider);
    final address = walletState.valueOrNull?.address ?? '';
    final publicKey = walletState.valueOrNull?.publicKey ?? '';
    final balanceState = ref.watch(balanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Text(
                'Profile',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),

              // ── Avatar ──────────────────────────────────────────────
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withAlpha(40),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Section 1: Label + Key + Buttons ─────────────────
              if (address.isNotEmpty) ...[
                Text(
                  'Your Public Key',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: Spacing.borderRadiusMd,
                  ),
                  child: SelectableText(
                    publicKey,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: publicKey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Public key copied')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final url = Uri.parse(
                          'https://explorer.solana.com/address/$publicKey?cluster=devnet',
                        );
                        launchUrl(url, mode: LaunchMode.inAppBrowserView);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Explorer'),
                    ),
                  ],
                ),
              ],

              // ── Section 2: QR Code ──────────────────────────────────
              if (address.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: Spacing.borderRadiusXl,
                    boxShadow: cardShadow,
                    border: Border.all(color: AppColors.border.withAlpha(60)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Scan to receive SOL',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: 'solana:$publicKey',
                        version: QrVersions.auto,
                        size: 200,
                        gapless: true,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.textPrimary,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // COMMENTED OUT SECTIONS:
              // Section 3: Wallet Balance card (uses SkeletonBox)
              // -- adding it back now --
              if (address.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Personal Wallet Balance',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      balanceState.when(
                        data: (balance) => AnimatedBalance(
                          balance: balance,
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        loading: () =>
                            const SkeletonBox(width: 160, height: 32),
                        error: (_, __) => Text(
                          'Unavailable',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Section 4: No-wallet fallback
              if (address.isEmpty) ...[
                const SizedBox(height: 40),
                Icon(
                  Icons.wallet_rounded,
                  size: 64,
                  color: AppColors.textTertiary.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  'No wallet loaded',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Section 5: Logout button
              if (address.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
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
              'Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'This will remove your wallet from this device. '
          'Your on-chain multisig will NOT be deleted. '
          'Make sure you have your recovery phrase saved.\n\n'
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
}
