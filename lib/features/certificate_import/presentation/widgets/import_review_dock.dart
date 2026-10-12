import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';

import 'import_error_banner.dart';

/// Bottom dock of the review: progress, the send error and ONE main action.
///
/// The action always leads somewhere: "Completar N filas" while rows are
/// incomplete, "Enviar a revisión" once everything is ready.
class ImportReviewDock extends StatelessWidget {
  const ImportReviewDock({
    super.key,
    required this.total,
    required this.readyCount,
    required this.onComplete,
    required this.onSend,
    this.isSending = false,
    this.error,
  });

  final int total;
  final int readyCount;
  final bool isSending;

  /// Translated send error, shown above the button without leaving the screen.
  final String? error;
  final VoidCallback onComplete;
  final VoidCallback onSend;

  int get _missing => total - readyCount;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final canSend = total > 0 && _missing == 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ImportErrorBanner(message: error),
              Text(
                'certificate_import.review.progress'.tr(namedArgs: {
                  'ready': '$readyCount',
                  'total': '$total',
                }),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 6),
              SacTweenedBar(
                value: total == 0 ? 0 : readyCount / total,
                color: c.success,
                backgroundColor: c.surfaceVariant,
              ),
              const SizedBox(height: 12),
              SacStateSwap(
                child: SacButton.primary(
                  key: ValueKey(canSend),
                  text: canSend
                      ? 'certificate_import.review.submit'.tr()
                      : (_missing == 1
                              ? 'certificate_import.review.complete_one'
                              : 'certificate_import.review.complete_other')
                          .tr(namedArgs: {'count': '$_missing'}),
                  isLoading: isSending,
                  onPressed: canSend ? onSend : onComplete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
