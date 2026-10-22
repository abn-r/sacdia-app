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
  }) : _restricted = false;

  /// Access restricted (403): lock icon, neutral tint, no retry by default.
  const SacErrorState.forbidden({
    super.key,
    this.title = '',
    this.message,
    this.onRetry,
    this.retryLabel,
    this.padding = const EdgeInsets.all(32),
  })  : icon = HugeIcons.strokeRoundedLockKey,
        _restricted = true;

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final HugeIconData icon;
  final EdgeInsetsGeometry padding;
  final bool _restricted;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final resolvedTitle = title.isNotEmpty
        ? title
        : (_restricted
            ? 'common.error_state.forbidden_title'.tr()
            : 'common.error_state.title'.tr());
    final resolvedMessage = message ??
        (_restricted ? 'common.error_state.forbidden_message'.tr() : null);
    final showRetry = onRetry != null;

    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
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
            if (resolvedMessage != null &&
                resolvedMessage.trim().isNotEmpty) ...[
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
        ),
      ),
    );
  }
}
