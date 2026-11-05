import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/user_honor.dart';
import '../providers/honors_providers.dart';
import 'honor_band_scaffold.dart';

enum _HonorMenuAction { abandon }

/// Smallest gap between the pull-down and the screen edge.
const double _menuEdgeInset = 12;

/// Gap between the button's touch target and its visible circle.
const double _circleInset = (SacTopBar.touchTarget - 30) / 2;

/// Top bar "more" button for an enrolled honor with the "leave honor" action.
///
/// It opens an iOS-style pull-down menu drawn with the design system pieces
/// (card surface, border and shadow, a tinted icon well) and then confirms
/// with a destructive [SacDialog] that recalls what the member would lose
/// ([progressSummary]).
///
/// Renders nothing when the honor can no longer be abandoned (under review or
/// approved). On success it shows feedback and, when [popOnSuccess] is true,
/// closes the current work screen since the enrollment no longer exists.
class HonorAbandonMenuButton extends ConsumerWidget {
  final UserHonor userHonor;
  final String honorName;
  final bool popOnSuccess;

  /// Color of the three-dots icon. Null follows the [HonorTopBarTone] of the
  /// honor band scaffold, or the secondary text color outside it.
  final Color? iconColor;

  /// What the member has done so far ("Llevas 3 de 5 requisitos (60 %)"),
  /// shown in the confirmation. Null when there is nothing to lose yet.
  final String? progressSummary;

  const HonorAbandonMenuButton({
    super.key,
    required this.userHonor,
    required this.honorName,
    this.popOnSuccess = true,
    this.iconColor,
    this.progressSummary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!userHonor.canAbandon) return const SizedBox.shrink();

    final c = context.sac;
    final isLoading = ref.watch(
      honorAbandonActionsNotifierProvider.select((s) => s.isLoading),
    );
    // Inside the honor band scaffold the bar says how it looks right now
    // (white over the band, dark over the page).
    final tone = HonorTopBarTone.maybeOf(context);
    final color = iconColor ?? tone?.foreground ?? c.textSecondary;
    final onBand = tone?.onBand ?? iconColor != null;

    return Semantics(
      button: true,
      enabled: !isLoading,
      label: 'honors.abandon.menu_tooltip'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('honor-abandon-menu'),
        behavior: HitTestBehavior.opaque,
        onTap: isLoading ? null : () => _openMenu(context, ref),
        child: SizedBox(
          width: SacTopBar.touchTarget,
          height: SacTopBar.touchTarget,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onBand
                    ? Colors.white.withValues(alpha: 0.22)
                    : c.surfaceVariant,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMoreHorizontal,
                size: 18,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final anchor = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final action = await showGeneralDialog<_HonorMenuAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: SacMotion.reduceMotionOf(context)
          ? SacMotion.reducedFade
          : SacMotion.modal,
      pageBuilder: (menuContext, _, __) => _HonorPullDownMenu(
        top: anchor.dy - 4,
        // Line the panel up with the visible circle, never flush with the
        // screen edge.
        right: math.max(
          _menuEdgeInset,
          overlay.size.width - anchor.dx + _circleInset,
        ),
      ),
      transitionBuilder: (menuContext, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: SacMotion.easeOut,
          reverseCurve: Curves.easeIn,
        );
        final fade = FadeTransition(opacity: curved, child: child);
        if (SacMotion.reduceMotionOf(menuContext)) return fade;
        return ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween<double>(begin: SacMotion.enterScale, end: 1)
              .animate(curved),
          child: fade,
        );
      },
    );
    if (action != _HonorMenuAction.abandon || !context.mounted) return;
    await _confirmAndAbandon(context, ref);
  }

  Future<void> _confirmAndAbandon(BuildContext context, WidgetRef ref) async {
    // Abandoning invalidates the enrollment, so the screen hosting this button
    // rebuilds without it. Feedback and navigation go through the navigator,
    // which outlives this widget.
    final navigator = Navigator.of(context);
    final notifier = ref.read(honorAbandonActionsNotifierProvider.notifier);

    final confirmed = await SacDialog.show(
      context,
      title: 'honors.abandon.confirm_title'.tr(),
      content:
          'honors.abandon.confirm_message'.tr(namedArgs: {'name': honorName}),
      highlight: progressSummary,
      confirmLabel: 'honors.abandon.confirm_cta'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    final user = ref.read(authNotifierProvider).value ??
        await ref.read(authNotifierProvider.future);
    if (!navigator.mounted) return;

    final userId = user?.id;
    if (userId == null) {
      SacSnackBar.show(navigator.context, 'honors.abandon.no_session'.tr(),
          isError: true);
      return;
    }

    final success =
        await notifier.abandon(userId: userId, honorId: userHonor.honorId);
    if (!navigator.mounted) return;

    SacSnackBar.show(
      navigator.context,
      success ? 'honors.abandon.success'.tr() : 'honors.abandon.error'.tr(),
      isError: !success,
    );

    // Navigator.pop skips PopScope guards (unsaved checklist edits no longer
    // matter once the enrollment is gone).
    if (success && popOnSuccess && navigator.canPop()) {
      navigator.pop();
    }
  }
}

/// The pull-down panel: anchored under the "more" button by its top-right
/// corner, card surface with the shared border and shadow.
class _HonorPullDownMenu extends StatelessWidget {
  const _HonorPullDownMenu({required this.top, required this.right});

  final double top;
  final double right;

  static const double _width = 280;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final maxWidth = MediaQuery.sizeOf(context).width - 24;

    // A dialog route has no Material above it; this gives the text its base
    // style.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            top: top,
            right: right,
            width: _width < maxWidth ? _width : maxWidth,
            child: Container(
              key: const ValueKey('honor-abandon-pull-down'),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: c.border.withValues(alpha: 0.65)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 34,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: _HonorMenuItem(
                icon: HugeIcons.strokeRoundedLogout03,
                label: 'honors.abandon.action'.tr(),
                hint: 'honors.abandon.action_hint'.tr(),
                onTap: () =>
                    Navigator.of(context).pop(_HonorMenuAction.abandon),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A destructive menu row: tinted round icon well, red label and a short hint.
/// It tints while pressed, like the rest of the press feedback in the app.
class _HonorMenuItem extends StatefulWidget {
  const _HonorMenuItem({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final HugeIconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  State<_HonorMenuItem> createState() => _HonorMenuItemState();
}

class _HonorMenuItemState extends State<_HonorMenuItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.hint,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('honor-abandon-action'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: SacMotion.reduceMotionOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _pressed
                ? c.errorContainer.withValues(alpha: 0.55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.errorContainer,
                  border: Border.all(color: c.error.withValues(alpha: 0.14)),
                ),
                child: HugeIcon(icon: widget.icon, size: 18, color: c.error),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: c.error,
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.hint,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: SacFontSize.labelSmall,
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
