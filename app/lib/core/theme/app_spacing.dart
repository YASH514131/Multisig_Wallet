import 'package:flutter/material.dart';

/// 8-pt spacing grid + consistent radii & durations.
abstract class Spacing {
  // ── Grid values ────────────────────────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ── Page padding ───────────────────────────────────────────────────────
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20);
  static const EdgeInsets pageAll = EdgeInsets.all(20);

  // ── Card padding ───────────────────────────────────────────────────────
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(20);

  // ── Radii ──────────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 999;

  static BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);

  // ── Durations ──────────────────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // ── Curves ─────────────────────────────────────────────────────────────
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
}

/// Convenience box-shadow list reused by cards.
List<BoxShadow> get cardShadow => const [
  BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
];
