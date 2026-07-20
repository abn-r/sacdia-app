import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// SACDIA custom dialog widget — iOS-inspired design with SACDIA color system.
///
/// Rounded corners, elevated white/dark surface, optional semantic icon,
/// clear copy hierarchy and touch-safe pill actions.
/// Use [SacDialog.show] for the common confirm/cancel pattern, or build
/// a fully custom content dialog with the widget directly via [showDialog].
///
/// Example:
/// ```dart
/// final confirmed = await SacDialog.show(
///   context,
///   title: 'Eliminar contacto',
///   content: '¿Estás seguro de que deseas eliminar este contacto?',
///   confirmLabel: 'Eliminar',
///   confirmIsDestructive: true,
/// );
/// if (confirmed == true) { ... }
/// ```
class SacDialog extends StatelessWidget {
  final String title;
  final String? content;
  final String? highlight;
  final List<List<dynamic>>? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final List<SacDialogAction> actions;

  const SacDialog({
    super.key,
    required this.title,
    this.content,
    this.highlight,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    required this.actions,
  });

  /// Shows a SACDIA-styled confirm/cancel dialog and returns the result.
  ///
  /// Returns `true` when the user taps the confirm action, `false` for cancel,
  /// and `null` when dismissed by tapping the barrier.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? content,
    required String confirmLabel,
    String? cancelLabel,
    bool confirmIsDestructive = false,
    String? highlight,
    List<List<dynamic>>? icon,
    Color? iconColor,
    Color? iconBackgroundColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: context.sac.barrierColor,
      barrierDismissible: true,
      builder: (context) => SacDialog(
        title: title,
        content: content,
        highlight: highlight,
        icon: icon ??
            (confirmIsDestructive
                ? HugeIcons.strokeRoundedAlert02
                : HugeIcons.strokeRoundedCheckmarkCircle02),
        iconColor: iconColor ??
            (confirmIsDestructive ? AppColors.error : AppColors.coral700),
        iconBackgroundColor: iconBackgroundColor ??
            (confirmIsDestructive ? AppColors.errorLight : AppColors.coral50),
        actions: [
          SacDialogAction(
            label: cancelLabel ?? tr('core.dialog.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            style: SacDialogActionStyle.cancel,
          ),
          SacDialogAction(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
            style: confirmIsDestructive
                ? SacDialogActionStyle.destructive
                : SacDialogActionStyle.confirm,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: _AnimatedDialogContent(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            decoration: BoxDecoration(
              color: context.sac.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: context.sac.border.withValues(alpha: 0.65),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: iconBackgroundColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (iconColor ?? AppColors.validatedDark)
                                  .withValues(alpha: 0.14),
                            ),
                          ),
                          child: HugeIcon(
                            icon: icon!,
                            size: 26,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: context.sac.text,
                          height: 1.15,
                        ),
                      ),
                      if (content != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          content!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: context.sac.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                      if (highlight != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: iconBackgroundColor ??
                                AppColors.primaryLight.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (iconColor ?? AppColors.primary)
                                  .withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            highlight!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: iconColor ?? AppColors.primary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: actions.length <= 2
                      ? Row(
                          children: _buildHorizontalActionButtons(context),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildVerticalActionButtons(context),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHorizontalActionButtons(BuildContext context) {
    final widgets = <Widget>[];

    for (int i = 0; i < actions.length; i++) {
      if (i > 0) widgets.add(const SizedBox(width: 10));
      widgets.add(Expanded(child: _ActionButton(action: actions[i])));
    }

    return widgets;
  }

  List<Widget> _buildVerticalActionButtons(BuildContext context) {
    final widgets = <Widget>[];

    for (int i = 0; i < actions.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 10));
      widgets.add(_ActionButton(action: actions[i]));
    }

    return widgets;
  }
}

/// Scale + fade entrance animation for the dialog.
class _AnimatedDialogContent extends StatefulWidget {
  final Widget child;

  const _AnimatedDialogContent({required this.child});

  @override
  State<_AnimatedDialogContent> createState() => _AnimatedDialogContentState();
}

class _AnimatedDialogContentState extends State<_AnimatedDialogContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.modal,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: SacMotion.easeOut,
    ).drive(Tween<double>(begin: SacMotion.enterScale, end: 1.0));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: SacMotion.easeOut,
    ).drive(Tween<double>(begin: 0.0, end: 1.0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduceMotion) return;

    final firstDependencyRead = _reduceMotion == null;
    _reduceMotion = reduceMotion;
    _controller.duration =
        reduceMotion ? SacMotion.reducedFade : SacMotion.modal;

    if (firstDependencyRead || !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fadedContent = FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );

    if (_reduceMotion == true) return fadedContent;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: fadedContent,
    );
  }
}

/// Visual style variants for [SacDialogAction].
enum SacDialogActionStyle {
  /// Primary confirm action.
  confirm,

  /// Destructive action.
  destructive,

  /// Secondary cancel action.
  cancel,
}

/// A single action button in a [SacDialog].
class SacDialogAction {
  final String label;
  final VoidCallback onPressed;
  final SacDialogActionStyle style;

  const SacDialogAction({
    required this.label,
    required this.onPressed,
    this.style = SacDialogActionStyle.confirm,
  });
}

class _ActionButton extends StatelessWidget {
  final SacDialogAction action;

  const _ActionButton({required this.action});

  Color _labelColor(BuildContext context) {
    switch (action.style) {
      case SacDialogActionStyle.confirm:
      case SacDialogActionStyle.destructive:
        return Colors.white;
      case SacDialogActionStyle.cancel:
        return context.sac.textSecondary;
    }
  }

  Color _backgroundColor(BuildContext context) {
    switch (action.style) {
      case SacDialogActionStyle.confirm:
        return AppColors.coral700;
      case SacDialogActionStyle.destructive:
        return AppColors.error;
      case SacDialogActionStyle.cancel:
        return Colors.transparent;
    }
  }

  FontWeight _fontWeight() {
    switch (action.style) {
      case SacDialogActionStyle.confirm:
      case SacDialogActionStyle.destructive:
        return FontWeight.w600;
      case SacDialogActionStyle.cancel:
        return FontWeight.w400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFilled = action.style != SacDialogActionStyle.cancel;

    return SizedBox(
      height: 48,
      child: isFilled
          ? FilledButton(
              onPressed: action.onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _backgroundColor(context),
                foregroundColor: _labelColor(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _ActionButtonLabel(
                label: action.label,
                color: _labelColor(context),
                fontWeight: _fontWeight(),
              ),
            )
          : TextButton(
              onPressed: action.onPressed,
              style: TextButton.styleFrom(
                foregroundColor: _labelColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _ActionButtonLabel(
                label: action.label,
                color: _labelColor(context),
                fontWeight: _fontWeight(),
              ),
            ),
    );
  }
}

class _ActionButtonLabel extends StatelessWidget {
  final String label;
  final Color color;
  final FontWeight fontWeight;

  const _ActionButtonLabel({
    required this.label,
    required this.color,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        fontWeight: fontWeight,
        color: color,
        height: 1.1,
      ),
    );
  }
}
