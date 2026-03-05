import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/wallet_controller.dart';
import '../../shared/widgets/common_widgets.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _mnemonicController = TextEditingController();
  String? _error;
  bool _suppressNav = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideUp = Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _mnemonicController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(walletControllerProvider, (prev, next) {
      if (next.hasError) {
        final message = next.error?.toString() ?? 'Unknown error';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }

      final hadWallet = prev?.valueOrNull != null;
      final hasWallet = next.valueOrNull != null;
      if (!hadWallet && hasWallet && !_suppressNav) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/main');
        });
      }
    });

    final walletState = ref.watch(walletControllerProvider);
    final isLoading = walletState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // ── Logo & Branding ────────────────────────────────────
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withAlpha(40),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'T',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'True Wallet',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure multisig treasury management\nfor institutional teams.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Create Wallet ──────────────────────────────────────
                  TactileButton(
                    onPressed: isLoading ? null : _createWallet,
                    isLoading: isLoading,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Create new wallet',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Divider ────────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or import existing',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Import ─────────────────────────────────────────────
                  TextField(
                    controller: _mnemonicController,
                    minLines: 2,
                    maxLines: 3,
                    style: GoogleFonts.jetBrainsMono(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Recovery phrase',
                      hintText: 'twelve or twenty-four words',
                      errorText: _error,
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton(
                    onPressed: isLoading ? null : _importWallet,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Import wallet',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Loading indicator ──────────────────────────────────
                  if (isLoading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Spacing.radiusFull),
                      child: const LinearProgressIndicator(
                        minHeight: 3,
                        color: AppColors.brand,
                        backgroundColor: AppColors.brandLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Reset ──────────────────────────────────────────────
                  Center(
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              await ref
                                  .read(walletControllerProvider.notifier)
                                  .clear();
                              _mnemonicController.clear();
                              setState(() => _error = null);
                            },
                      child: Text(
                        'Reset stored wallet',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createWallet() async {
    setState(() => _error = null);
    _suppressNav = true;
    HapticFeedback.mediumImpact();

    await ref.read(walletControllerProvider.notifier).createNew();
    final account = ref.read(walletControllerProvider).valueOrNull;
    if (!mounted || account == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: Spacing.borderRadiusXl),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: Spacing.borderRadiusMd,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Save your recovery phrase',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Write this down and store it safely. Anyone with these words can access your funds.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: Spacing.borderRadiusMd,
                ),
                child: SelectableText(
                  account.mnemonic,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TactileButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: account.mnemonic));
                  Navigator.of(ctx).pop();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.copy_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Copy & Continue',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (mounted) {
      _suppressNav = false;
      context.go('/main');
    }
  }

  Future<void> _importWallet() async {
    final phrase = _mnemonicController.text;
    setState(() => _error = null);

    if (phrase.trim().split(' ').length < 12) {
      setState(() => _error = 'Enter a full recovery phrase');
      return;
    }

    HapticFeedback.mediumImpact();
    try {
      await ref.read(walletControllerProvider.notifier).importMnemonic(phrase);
    } catch (e) {
      setState(() => _error = 'Invalid recovery phrase');
    }
  }
}
