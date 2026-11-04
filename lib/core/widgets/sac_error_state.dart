import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

/// Canonical full-area error placeholder.
///
/// Counterpart of `SacEmptyState` for failed loads: centered icon (56), title,
/// optional explanation and an optional retry [SacButton]. Never pass a raw
/// `error.toString()` as [message]; use a localized sentence that says what
/// happened and what to do next.
///
/// [SacErrorState.forbidden] covers HTTP 403: a lock icon, "access restricted"
/// copy and no retry (retrying cannot fix a missing permission).
///
/// [scrollable] (default false) wraps the content in an always-scrollable view
/// that fills the viewport, so it stays centered AND pull-to-refresh works when
/// it is the child of a `RefreshIndicator`.
///
/// [SacErrorState.inline] is the compact form for panels and cards: small icon,
/// message and a small outline retry.
///
/// ```dart
/// RefreshIndicator(
///   onRefresh: refresh,
///   child: SacErrorState(title: t, onRetry: refresh, scrollable: true),
/// )
/// SacErrorState.inline(message: 'No se pudo cargar', onRetry: refresh)
/// ```
///
/// [padding] lets the state sit below a frosted top bar, e.g. with
/// `SacTopBar.paddingBelowBar(context, const EdgeInsets.all(32))`.
class SacErrorState extends StatelessWidget {
  const SacErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = HugeIcons.strokeRoundedAlert02,
    this.padding = const EdgeInsets.all(32),
    this.scrollable = false,
  })  : _restricted = false,
        _inline = false;

  /// Compact error for panels/cards. Not scrollable, no big padding.
  const SacErrorState.inline({
    super.key,
    required String message,
    this.onRetry,
  })  : title = '',
        // ignore: prefer_initializing_formals
        message = message,
        retryLabel = null,
        icon = HugeIcons.strokeRoundedAlert02,
        padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        scrollable = false,
        _restricted = false,
        _inline = true;

  /// Access restricted (403): lock icon, neutral tint, no retry by default.
  const SacErrorState.forbidden({
    super.key,
    this.title = '',
    this.message,
    this.onRetry,
    this.retryLabel,
    this.padding = const EdgeInsets.all(32),
    this.scrollable = false,
  })  : icon = HugeIcons.strokeRoundedLockKey,
        _restricted = true,
        _inline = false;

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final HugeIconData icon;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final bool _restricted;
  final bool _inline;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    if (_inline) return _buildInline(context);
    final theme = Theme.of(context).textTheme;
    final resolvedTitle = title.isNotEmpty
        ? title
        : (_restricted
            ? 'common.error_state.forbidden_title'.tr()
            : 'common.error_state.title'.tr());
    final resolvedMessage = message ??
        (_restricted ? 'common.error_state.forbidden_message'.tr() : null);
    final showRetry = onRetry != null;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: HugeIcon(
            icon: icon,
            size: 56,
            color: _restricted ? c.textTertiary : c.error,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          resolvedTitle,
          style: theme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
          textAlign: TextAlign.center,
        ),
        if (resolvedMessage != null && resolvedMessage.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            resolvedMessage,
            style: theme.bodyMedium?.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        if (showRetry) ...[
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: SacButton.primary(
              text: retryLabel ?? 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ),
        ],
      ],
    );

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

    return Center(
      child: SingleChildScrollView(padding: padding, child: content),
    );
  }

  Widget _buildInline(BuildContext context) {
    final c = context.sac;
    final text = message ?? '';
    return Padding(
      padding: padding,
      child: Row(
        children: [
          ExcludeSemantics(
            child: HugeIcon(icon: icon, size: 20, color: c.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            SacButton(
              text: 'common.retry'.tr(),
              size: SacButtonSize.small,
              variant: SacButtonVariant.outline,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
