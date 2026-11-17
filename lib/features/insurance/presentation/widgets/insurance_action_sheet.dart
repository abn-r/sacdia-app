import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_sheet.dart';

/// Bottom sheet that explains what is about to happen and asks to confirm.
///
/// Returns `true` for the primary action, `false` for the secondary one and
/// `null` when dismissed. [body] is already translated; [content] goes under
/// it (a list of people, for instance).
Future<bool?> showInsuranceActionSheet(
  BuildContext context, {
  required String title,
  required String primaryLabel,
  String? body,
  Widget? content,
  String? secondaryLabel,
  dynamic primaryIcon,
  bool destructive = false,
}) {
  return showSacSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => InsuranceActionSheet(
      title: title,
      body: body,
      content: content,
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
      primaryIcon: primaryIcon,
      destructive: destructive,
    ),
  );
}

class InsuranceActionSheet extends StatelessWidget {
  const InsuranceActionSheet({
    super.key,
    required this.title,
    required this.primaryLabel,
    this.body,
    this.content,
    this.secondaryLabel,
    this.primaryIcon,
    this.destructive = false,
  });

  final String title;
  final String? body;
  final Widget? content;
  final String primaryLabel;
  final String? secondaryLabel;
  final dynamic primaryIcon;

  /// Red primary action (cancel, delete): the consequence is irreversible.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final body = this.body;
    final content = this.content;
    final secondaryLabel = this.secondaryLabel;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SacSheetGrabber(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: SacFontSize.titleLarge,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: c.text,
                        ),
                      ),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: SacFontSize.titleSmall,
                          height: 1.45,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                    if (content != null) ...[
                      const SizedBox(height: 12),
                      content,
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (destructive)
                    SacButton.destructive(
                      text: primaryLabel,
                      icon: primaryIcon,
                      onPressed: () => Navigator.of(context).pop(true),
                    )
                  else
                    SacButton.primary(
                      text: primaryLabel,
                      icon: primaryIcon,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  if (secondaryLabel != null) ...[
                    const SizedBox(height: 8),
                    SacButton.outline(
                      text: secondaryLabel,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
