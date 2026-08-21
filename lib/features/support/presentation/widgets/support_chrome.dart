import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

AppBar supportAppBar(BuildContext context, {required String title}) {
  final c = context.sac;
  return AppBar(
    automaticallyImplyLeading: false,
    leading: sacAutoBackButton(context),
    backgroundColor: c.background.withValues(alpha: 0.92),
    foregroundColor: c.text,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    title: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 17,
        letterSpacing: -0.3,
        color: c.text,
      ),
    ),
  );
}

/// Press scale on pointer-down. [onTap] is optional so nested controls keep
/// their own gesture arena (same idea as ClubView).
class SupportPressable extends StatefulWidget {
  const SupportPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.semanticButton = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;
  final bool semanticButton;

  @override
  State<SupportPressable> createState() => _SupportPressableState();
}

class _SupportPressableState extends State<SupportPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant SupportPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    Widget child = AnimatedScale(
      scale: (!reduce && _pressed && widget.enabled) ? SacMotion.pressScale : 1,
      duration: SacMotion.press,
      curve: SacMotion.easeOut,
      child: widget.child,
    );

    child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTap: widget.enabled && widget.onTap != null
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: child,
    );

    if (widget.semanticLabel == null) return child;

    return Semantics(
      button: widget.semanticButton,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: child,
    );
  }
}

class SupportDestination {
  const SupportDestination({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final HugeIconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// iOS Settings-style grouped rows: highlight on press, no scale
/// (scaling a row inside a shared card leaves siblings behind).
class SupportDestinationList extends StatelessWidget {
  const SupportDestinationList({super.key, required this.items});

  final List<SupportDestination> items;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 70,
                  color: c.borderLight,
                ),
              _DestinationRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _DestinationRow extends StatefulWidget {
  const _DestinationRow({required this.item});

  final SupportDestination item;

  @override
  State<_DestinationRow> createState() => _DestinationRowState();
}

class _DestinationRowState extends State<_DestinationRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final item = widget.item;

    return Semantics(
      button: true,
      label: '${item.title}. ${item.subtitle}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          item.onTap();
        },
        child: AnimatedContainer(
          duration: SacMotion.press,
          curve: SacMotion.easeOut,
          color: (!reduce && _pressed) ? c.surfaceVariant : Colors.transparent,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.iconBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: item.icon,
                    color: item.iconColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: c.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
