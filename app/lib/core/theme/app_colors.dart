import 'package:flutter/material.dart';

/// Premium fintech colour palette — muted, professional, trust-inducing.
abstract class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color brand = Color(0xFF6C5CE7); // Soft purple
  static const Color brandLight = Color(0xFFEAE6FD);
  static const Color brandDark = Color(0xFF4A3DB8);

  // ── Surfaces ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F1F5);
  static const Color card = Color(0xFFFFFFFF);

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnBrand = Color(0xFFFFFFFF);

  // ── Status ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEFCE8);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoBg = Color(0xFFEFF6FF);

  // ── Pending / Governance / Executed ────────────────────────────────────
  static const Color pending = Color(0xFF3B82F6);
  static const Color pendingBg = Color(0xFFEFF6FF);
  static const Color governance = Color(0xFFF59E0B);
  static const Color governanceBg = Color(0xFFFEFCE8);
  static const Color executed = Color(0xFF22C55E);
  static const Color executedBg = Color(0xFFECFDF5);

  // ── Borders & Dividers ─────────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // ── Shimmer ────────────────────────────────────────────────────────────
  static const Color shimmerBase = Color(0xFFF1F5F9);
  static const Color shimmerHighlight = Color(0xFFE2E8F0);

  // ── Misc ───────────────────────────────────────────────────────────────
  static const Color shadow = Color(0x0A0F172A);
  static const Color overlay = Color(0x33000000);

  /// Gradient used for the vault / hero balance card.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF6)],
  );
}
