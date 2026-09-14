import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

/// Canonical empty / no-data placeholder.
///
/// Icon 56, title 17/w600, optional body 14 secondary, optional [SacButton].
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
  });

  final String title;
  final String? body;
  final dynamic icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final dynamic actionIcon;
  final SacButtonVariant actionVariant;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final showAction = actionLabel != null && onAction != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
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
                    fontSize: 17,
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
                      fontSize: 14,
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
        ),
      ),
    );
  }
}
