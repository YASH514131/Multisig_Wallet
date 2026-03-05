import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';

/// Full-screen success modal with Lottie animation.
///
/// Usage:
/// ```dart
/// await SuccessAnimationDialog.show(
///   context: context,
///   message: 'Proposal Executed Successfully',
/// );
/// ```
class SuccessAnimationDialog extends StatefulWidget {
  const SuccessAnimationDialog({
    super.key,
    required this.message,
    this.subtitle,
    this.txSignature,
    this.autoCloseDuration = const Duration(seconds: 3),
  });

  final String message;
  final String? subtitle;
  final String? txSignature;
  final Duration autoCloseDuration;

  /// Show the success animation modal and wait for it to auto-close.
  static Future<void> show({
    required BuildContext context,
    required String message,
    String? subtitle,
    String? txSignature,
    Duration autoCloseDuration = const Duration(seconds: 3),
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => SuccessAnimationDialog(
        message: message,
        subtitle: subtitle,
        txSignature: txSignature,
        autoCloseDuration: autoCloseDuration,
      ),
    );
  }

  @override
  State<SuccessAnimationDialog> createState() => _SuccessAnimationDialogState();
}

class _SuccessAnimationDialogState extends State<SuccessAnimationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Auto-close after duration
    Future.delayed(widget.autoCloseDuration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withAlpha(30),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie animation
              SizedBox(
                width: 200,
                height: 200,
                child: Lottie.network(
                  'https://lottie.host/be49a44d-46b4-47ce-96e8-174ef979fd0f/rVlExdvvX0.json',
                  repeat: false,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback: animated check icon
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, _) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              color: AppColors.successBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 64,
                              color: AppColors.success,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Message
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text('🚀', style: TextStyle(fontSize: 24)),

              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              if (widget.txSignature != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_long_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _truncateSig(widget.txSignature!),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _truncateSig(String sig) {
    if (sig.length <= 20) return sig;
    return '${sig.substring(0, 10)}...${sig.substring(sig.length - 10)}';
  }
}

/// Shows an error dialog when a transaction fails.
class TransactionErrorDialog extends StatelessWidget {
  const TransactionErrorDialog({super.key, required this.errorMessage});

  final String errorMessage;

  static Future<void> show({
    required BuildContext context,
    required String errorMessage,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TransactionErrorDialog(errorMessage: errorMessage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.errorBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Transaction Failed',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
