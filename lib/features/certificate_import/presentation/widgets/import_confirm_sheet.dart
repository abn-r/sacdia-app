import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

/// Confirmation in a sheet. The primary action uses the accent color; only
/// [destructive] (removing something) turns it red. Returns true when the
/// member confirms, false or null otherwise.
Future<bool?> showImportConfirmSheet(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) {
  return showSacSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ImportConfirmSheet(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
}

class _ImportConfirmSheet extends StatelessWidget {
  const _ImportConfirmSheet({
    required this.title,
    this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String? body;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    void close(bool value) => Navigator.of(context).pop(value);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(title: title),
            if (body != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(
                  body!,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    height: 1.4,
                    color: c.textSecondary,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  destructive
                      ? SacButton.destructive(
                          text: confirmLabel,
                          onPressed: () => close(true),
                        )
                      : SacButton.primary(
                          text: confirmLabel,
                          onPressed: () => close(true),
                        ),
                  const SizedBox(height: 8),
                  SacButton.ghost(
                    text: cancelLabel,
                    onPressed: () => close(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
