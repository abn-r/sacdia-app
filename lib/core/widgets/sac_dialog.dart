import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// SACDIA custom dialog widget — iOS-inspired design with SACDIA color system.
///
/// Rounded corners (20px), white/dark surface, title in [AppColors.primary],
/// iOS-style action buttons separated by thin divider lines.
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
  final List<SacDialogAction> actions;

  const SacDialog({
    super.key,
    required this.title,
    this.content,
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
    String cancelLabel = 'Cancelar',
    bool confirmIsDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (context) => SacDialog(
        title: title,
        content: content,
        actions: [
          SacDialogAction(
            label: cancelLabel,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: _AnimatedDialogContent(
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title and content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    if (content != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        content!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: context.sac.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Thin top divider before actions
              Container(
                height: 0.5,
                color: context.sac.border,
              ),

              // Action buttons — iOS-style row layout
              IntrinsicHeight(
                child: Row(
                  children: _buildActionButtons(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    final widgets = <Widget>[];

    for (int i = 0; i < actions.length; i++) {
      if (i > 0) {
        // Vertical divider between buttons
        widgets.add(
          Builder(builder: (ctx) => Container(
            width: 0.5,
            color: ctx.sac.border,
          )),
        );
      }
      widgets.add(Expanded(child: _ActionButton(action: actions[i])));
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.82, end: 1.0));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ).drive(Tween<double>(begin: 0.0, end: 1.0));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Visual style variants for [SacDialogAction].
enum SacDialogActionStyle {
  /// Primary confirm action — uses [AppColors.primary].
  confirm,

  /// Destructive action — uses [AppColors.error].
  destructive,

  /// Secondary cancel action — uses [AppColors.lightTextSecondary].
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
        return AppColors.primary;
      case SacDialogActionStyle.destructive:
        return AppColors.error;
      case SacDialogActionStyle.cancel:
        return context.sac.textSecondary;
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
    return TextButton(
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _labelColor(context),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(
        action.label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: _fontWeight(),
          color: _labelColor(context),
        ),
      ),
    );
  }
}
