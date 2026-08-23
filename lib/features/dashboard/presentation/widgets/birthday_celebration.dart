import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/celebration_overlay.dart';
import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/birthday_utils.dart';
import '../../../../core/widgets/sac_button.dart';
import '../providers/birthday_celebration_provider.dart';

class BirthdayCelebrationGate extends ConsumerStatefulWidget {
  const BirthdayCelebrationGate({super.key});

  @override
  ConsumerState<BirthdayCelebrationGate> createState() =>
      _BirthdayCelebrationGateState();
}

class _BirthdayCelebrationGateState
    extends ConsumerState<BirthdayCelebrationGate> {
  Timer? _midnightTimer;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer(durationUntilNextLocalDay(DateTime.now()), () {
      if (!mounted) return;
      _autoPrompted = false;
      ref.invalidate(birthdayCelebrationProvider);
      _scheduleMidnightRefresh();
    });
  }

  Future<void> _openBirthdayDialog() async {
    if (!mounted) return;

    await showBirthdayCelebrationDialog(
      context,
      onDismissForToday: () =>
          ref.read(birthdayCelebrationProvider.notifier).dismissForToday(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(birthdayCelebrationProvider).valueOrNull;
    final shouldShow = state?.shouldShowEntryPoint ?? false;

    if (shouldShow && !_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openBirthdayDialog();
      });
    }

    if (!shouldShow) return const SizedBox.shrink();

    return BirthdayCelebrationBanner(onTap: _openBirthdayDialog);
  }
}

class BirthdayCelebrationBanner extends StatefulWidget {
  final VoidCallback onTap;

  const BirthdayCelebrationBanner({super.key, required this.onTap});

  @override
  State<BirthdayCelebrationBanner> createState() =>
      _BirthdayCelebrationBannerState();
}

class _BirthdayCelebrationBannerState extends State<BirthdayCelebrationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || SacMotion.reduceMotionOf(context)) return;
      _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !SacMotion.reduceMotionOf(context);

    return Semantics(
      button: true,
      label: tr('dashboard.birthday.banner_semantics'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: widget.onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.55),
                width: 1,
              ),
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.24),
                  AppColors.primary.withValues(alpha: 0.12),
                  c.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _AnimatedBirthdayIcon(
                  controller: _controller,
                  shouldAnimate: shouldAnimate,
                  compact: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('dashboard.birthday.banner_title'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: c.text,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('dashboard.birthday.banner_body'),
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedMagicWand01,
                  color: AppColors.accentDark,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showBirthdayCelebrationDialog(
  BuildContext context, {
  required Future<void> Function() onDismissForToday,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: context.sac.barrierColor,
    builder: (dialogContext) => _BirthdayCelebrationDialog(
      onDismissForToday: onDismissForToday,
    ),
  );
}

class _BirthdayCelebrationDialog extends StatefulWidget {
  final Future<void> Function() onDismissForToday;

  const _BirthdayCelebrationDialog({required this.onDismissForToday});

  @override
  State<_BirthdayCelebrationDialog> createState() =>
      _BirthdayCelebrationDialogState();
}

class _BirthdayCelebrationDialogState extends State<_BirthdayCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _confettiTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || SacMotion.reduceMotionOf(context)) return;
      _controller.repeat(reverse: true);
      _showConfettiBurst();
      _confettiTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) _showConfettiBurst();
      });
    });
  }

  void _showConfettiBurst() {
    CelebrationOverlay.show(
      context,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void dispose() {
    _confettiTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismissForToday() async {
    await widget.onDismissForToday();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !SacMotion.reduceMotionOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              if (shouldAnimate) const _DecorativeConfettiField(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AnimatedBirthdayIcon(
                      controller: _controller,
                      shouldAnimate: shouldAnimate,
                    ),
                    const SizedBox(height: 18),
                    _GoldShimmerText(
                      text: tr('dashboard.birthday.title'),
                      controller: _controller,
                      shouldAnimate: shouldAnimate,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('dashboard.birthday.message'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        tr('dashboard.birthday.bible_message'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.accentDark,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SacButton.primary(
                      text: tr('dashboard.birthday.thanks'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: HugeIcons.strokeRoundedFavouriteCircle,
                      backgroundColor: AppColors.accentDark,
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: _dismissForToday,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedViewOff,
                        size: 13,
                        color: AppColors.accentDark,
                      ),
                      label: Text(
                        tr('dashboard.birthday.dismiss_today'),
                        style: const TextStyle(
                          color: AppColors.accentDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
  }
}

class _AnimatedBirthdayIcon extends StatelessWidget {
  final AnimationController controller;
  final bool shouldAnimate;
  final bool compact;

  const _AnimatedBirthdayIcon({
    required this.controller,
    required this.shouldAnimate,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 56.0 : 108.0;
    final iconSize = compact ? 30.0 : 58.0;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final lift =
            shouldAnimate ? math.sin(controller.value * math.pi) * 6 : 0.0;
        final rotation = shouldAnimate
            ? math.sin(controller.value * math.pi * 2) * 0.06
            : 0.0;
        return Transform.translate(
          offset: Offset(0, -lift),
          child: Transform.rotate(angle: rotation, child: child),
        );
      },
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF7D6), Color(0xFFFFD47A), AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.34),
              blurRadius: compact ? 12 : 26,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedBirthdayCake,
          color: AppColors.accentDark,
          size: iconSize,
        ),
      ),
    );
  }
}

class _GoldShimmerText extends StatelessWidget {
  final String text;
  final AnimationController controller;
  final bool shouldAnimate;

  const _GoldShimmerText({
    required this.text,
    required this.controller,
    required this.shouldAnimate,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.headlineMedium;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offset = shouldAnimate ? controller.value : 0.15;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              Color(0xFF9A650F),
              Color(0xFFF8B84E),
              Color(0xFFFFF6C7),
              Color(0xFFD88A18),
            ],
            stops: [
              (offset - 0.25).clamp(0.0, 1.0),
              offset.clamp(0.0, 1.0),
              (offset + 0.18).clamp(0.0, 1.0),
              1,
            ],
          ).createShader(bounds),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: baseStyle?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: (baseStyle.fontSize ?? 28) * 1.25,
              letterSpacing: -0.7,
              height: 1.02,
            ),
          ),
        );
      },
    );
  }
}

class _DecorativeConfettiField extends StatelessWidget {
  const _DecorativeConfettiField();

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.42,
          child: Stack(
            children: List.generate(18, (index) {
              final top = 14.0 + (index % 6) * 22;
              final left = 18.0 + (index * 29) % 320;
              return Positioned(
                top: top,
                left: left,
                child: Transform.rotate(
                  angle: index * 0.42,
                  child: Container(
                    width: index.isEven ? 10 : 7,
                    height: index.isEven ? 6 : 10,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
