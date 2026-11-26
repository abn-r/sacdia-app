import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_button.dart';

/// The actions of a decision, stacked: one primary button and, under it, the
/// secondary action as plain text. [secondaryDestructive] paints it red
/// («Rechazar»); otherwise it uses the neutral text color («Cancelar»).
///
/// No side-by-side pair: the primary is the one thing to press and the other
/// is clearly lesser. Lives in a [SupervisionSheetFooter] or a
/// `SacFrostedFooter`.
class SupervisionStackedActions extends StatelessWidget {
  const SupervisionStackedActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.secondaryDestructive = true,
    this.isLoading = false,
    this.primaryDestructive = false,
  });

  final String primaryLabel;
  final HugeIconData? primaryIcon;
  final VoidCallback? onPrimary;

  /// Paints the primary button red (a rejection that is the main action).
  final bool primaryDestructive;

  final String? secondaryLabel;
  final HugeIconData? secondaryIcon;
  final VoidCallback? onSecondary;
  final bool secondaryDestructive;

  /// Disables both buttons and shows the spinner on the primary.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final secondary = secondaryLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primaryDestructive)
          SacButton.destructive(
            text: primaryLabel,
            icon: primaryIcon,
            labelMaxLines: 2,
            isLoading: isLoading,
            onPressed: isLoading ? null : onPrimary,
          )
        else
          SacButton.primary(
            text: primaryLabel,
            icon: primaryIcon,
            labelMaxLines: 2,
            isLoading: isLoading,
            onPressed: isLoading ? null : onPrimary,
          ),
        if (secondary != null) ...[
          const SizedBox(height: 4),
          // Full width so a long label wraps instead of overflowing.
          SacButton(
            text: secondary,
            icon: secondaryIcon,
            variant: SacButtonVariant.ghost,
            fullWidth: true,
            textColor: secondaryDestructive ? c.error : c.text,
            labelMaxLines: 2,
            isEnabled: !isLoading,
            onPressed: onSecondary,
          ),
        ],
      ],
    );
  }
}

/// Footer of a bottom sheet: clear of the home indicator, with the sheet's
/// 20 side inset. Also fine for a single button.
class SupervisionSheetFooter extends StatelessWidget {
  const SupervisionSheetFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: child,
      ),
    );
  }
}

/// A failure of an action, inside the sheet that ran it (the snackbar would
/// stay behind the modal). Announced when it appears.
class SupervisionInlineError extends StatelessWidget {
  const SupervisionInlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            height: 1.35,
            color: context.sac.error,
          ),
        ),
      ),
    );
  }
}
