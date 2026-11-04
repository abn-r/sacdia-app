import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Canonical empty / no-data placeholder.
///
/// Icon 56, title 17/w600, optional body 14 secondary, optional [SacButton].
///
/// [scrollable] (default false) wraps the content in an always-scrollable view
/// that fills the viewport: stays centered AND pull-to-refresh works as the
/// child of a `RefreshIndicator`. [SacEmptyState.inline] is the compact form
/// for panels/cards (small icon, title, optional body, no action).
///
/// ```dart
/// RefreshIndicator(
///   onRefresh: refresh,
///   child: SacEmptyState(title: t, scrollable: true),
/// )
/// SacEmptyState.inline(title: 'Sin registros')
/// ```
class SacEmptyState extends StatelessWidget {
  const SacEmptyState({
    super.key,
    required this.title,
    this.body,
    this.icon = HugeIcons.strokeRoundedInbox,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.actionVariant = SacButtonVariant.primary,
    this.scrollable = false,
  }) : _inline = false;

  /// Compact empty state for panels/cards. Not scrollable, no action.
  const SacEmptyState.inline({
    super.key,
    required this.title,
    this.body,
    this.icon = HugeIcons.strokeRoundedInbox,
  })  : actionLabel = null,
        onAction = null,
        actionIcon = null,
        actionVariant = SacButtonVariant.primary,
        scrollable = false,
        _inline = true;

  final String title;
  final String? body;
  final HugeIconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final HugeIconData? actionIcon;
  final bool scrollable;
  final bool _inline;
  final SacButtonVariant actionVariant;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final showAction = actionLabel != null && onAction != null;
    if (_inline) return _buildInline(context);

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: icon,
          size: 56,
          color: c.textTertiary,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: SacFontSize.titleLarge,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
          textAlign: TextAlign.center,
        ),
        if (body != null && body!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: SacFontSize.titleSmall,
                  color: c.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
        if (showAction) ...[
          const SizedBox(height: 24),
          SacButton(
            text: actionLabel!,
            icon: actionIcon ?? HugeIcons.strokeRoundedAdd01,
            variant: actionVariant,
            fullWidth: false,
            onPressed: onAction,
          ),
        ],
      ],
    );

    const padding = EdgeInsets.all(32);
    if (scrollable) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? (constraints.maxHeight - padding.vertical)
                      .clamp(0.0, double.infinity)
                  : 0,
            ),
            child: Center(child: content),
          ),
        ),
      );
    }
    return Center(child: Padding(padding: padding, child: content));
  }

  Widget _buildInline(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: HugeIcon(icon: icon, size: 24, color: c.textTertiary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                if (body != null && body!.trim().isNotEmpty)
                  Text(
                    body!,
                    style: textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
