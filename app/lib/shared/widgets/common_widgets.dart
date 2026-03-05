import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Skeleton / shimmer placeholder that mimics the shape of real content.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius ?? Spacing.borderRadiusSm,
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
                end: Alignment(1.0 + 2.0 * _animation.value, 0),
                colors: const [
                  AppColors.shimmerBase,
                  AppColors.shimmerHighlight,
                  AppColors.shimmerBase,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A card-shaped skeleton placeholder.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 84});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Spacing.borderRadiusLg,
        boxShadow: cardShadow,
      ),
      clipBehavior: Clip.hardEdge,
      padding: Spacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          SkeletonBox(width: 100, height: 12),
          SizedBox(height: 8),
          SkeletonBox(width: 160, height: 12),
        ],
      ),
    );
  }
}

/// Animating balance number that counts up.
class AnimatedBalance extends StatelessWidget {
  const AnimatedBalance({
    super.key,
    required this.balance,
    required this.style,
    this.duration = const Duration(milliseconds: 800),
    this.prefix = '',
    this.suffix = ' SOL',
    this.decimals = 4,
  });

  final double balance;
  final TextStyle style;
  final Duration duration;
  final String prefix;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: balance),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          '$prefix${value.toStringAsFixed(decimals)}$suffix',
          style: style,
        );
      },
    );
  }
}

/// Premium status badge with rounded-pill shape.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.icon,
  });

  factory StatusBadge.executed() => const StatusBadge(
    label: 'Executed',
    color: AppColors.executed,
    backgroundColor: AppColors.executedBg,
    icon: Icons.check_circle_rounded,
  );

  factory StatusBadge.pending() => const StatusBadge(
    label: 'Pending',
    color: AppColors.pending,
    backgroundColor: AppColors.pendingBg,
    icon: Icons.schedule_rounded,
  );

  factory StatusBadge.governance() => const StatusBadge(
    label: 'Governance',
    color: AppColors.governance,
    backgroundColor: AppColors.governanceBg,
    icon: Icons.gavel_rounded,
  );

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(Spacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass-morphic surface card used across the app.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding ?? Spacing.cardPadding,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Spacing.borderRadiusLg,
        boxShadow: cardShadow,
        border: Border.all(color: AppColors.border.withAlpha(60)),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: Spacing.borderRadiusLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: Spacing.borderRadiusLg,
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Tactile button with micro scale-down on press.
class TactileButton extends StatefulWidget {
  const TactileButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.foregroundColor,
    this.isLoading = false,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final Color? foregroundColor;
  final bool isLoading;
  final bool enabled;

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!mounted) return;
    _controller.forward().then((_) {
      if (!mounted) return;
      _controller.reverse();
    });
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.enabled && !widget.isLoading;
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(scale: _scale.value, child: child);
      },
      child: FilledButton(
        onPressed: isActive ? _handleTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: widget.color ?? AppColors.brand,
          foregroundColor: widget.foregroundColor ?? AppColors.textOnBrand,
        ),
        child: widget.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnBrand,
                ),
              )
            : widget.child,
      ),
    );
  }
}

/// Compact address display with copy & truncation.
class AddressChip extends StatelessWidget {
  const AddressChip({super.key, required this.address, this.maxLength = 12});

  final String address;
  final int maxLength;

  String get _truncated {
    if (address.length <= maxLength) return address;
    final half = (maxLength - 3) ~/ 2;
    return '${address.substring(0, half)}...${address.substring(address.length - half)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(Spacing.radiusFull),
      ),
      child: Text(
        _truncated,
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// A linear progress bar showing approval progress (e.g., 2 / 3 signers).
class ApprovalProgressBar extends StatelessWidget {
  const ApprovalProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$current / $total approvals',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: progress >= 1.0 ? AppColors.success : AppColors.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(Spacing.radiusFull),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: Spacing.normal,
            curve: Spacing.defaultCurve,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1.0 ? AppColors.success : AppColors.brand,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Quick-action circle button (Send / Receive / Propose).
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brand;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: c, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
