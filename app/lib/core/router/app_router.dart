import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/governance/governance_page.dart';
import '../../presentation/init/init_multisig_page.dart';
import '../../presentation/onboarding/onboarding_page.dart';
import '../../presentation/proposals/proposal_detail_page.dart';
import '../../presentation/qr/qr_display_page.dart';
import '../../presentation/send/send_sol_page.dart';
import '../../presentation/shell/main_shell.dart';

CustomTransitionPage<void> _fadeScale(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'onboarding',
      pageBuilder: (context, state) =>
          _fadeScale(state, const OnboardingPage()),
    ),
    // ── Main shell with bottom navigation ──────────────────────────────
    GoRoute(
      path: '/main',
      name: 'main',
      pageBuilder: (context, state) => _fadeScale(state, const MainShell()),
      routes: [
        GoRoute(
          path: 'proposal/:id',
          name: 'proposal',
          pageBuilder: (context, state) {
            final proposalId = state.pathParameters['id'] ?? 'unknown';
            return _slideUp(state, ProposalDetailPage(proposalId: proposalId));
          },
        ),
        GoRoute(
          path: 'governance',
          name: 'governance',
          pageBuilder: (context, state) =>
              _slideUp(state, const GovernancePage()),
        ),
        GoRoute(
          path: 'send',
          name: 'send',
          pageBuilder: (context, state) => _slideUp(state, const SendSolPage()),
        ),
        GoRoute(
          path: 'receive',
          name: 'receive',
          pageBuilder: (context, state) =>
              _slideUp(state, const QrDisplayPage()),
        ),
        GoRoute(
          path: 'init-multisig',
          name: 'init-multisig',
          pageBuilder: (context, state) =>
              _slideUp(state, const InitMultisigPage()),
        ),
      ],
    ),
    // ── Legacy redirect ────────────────────────────────────────────────
    GoRoute(path: '/dashboard', redirect: (context, state) => '/main'),
  ],
);
