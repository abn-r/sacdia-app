import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

import '../providers/master_honor_modal_queue_provider.dart';

/// Modal compacto para cambios de estado de maestrías recibidos por push.
class MasterHonorChangeModal extends StatelessWidget {
  const MasterHonorChangeModal({
    super.key,
    required this.event,
    this.onConfirm,
  });

  final MasterHonorModalEvent event;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.primaryLight)
                        .withValues(alpha: 0.9),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🏅', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.body,
              style: const TextStyle(fontSize: 15, height: 1.35),
            ),
            if (event.isPlural) ...[
              const SizedBox(height: 10),
              ...event.masterHonorNames.map(
                (name) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: _SummaryLine(name: name),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onConfirm,
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: HugeIcon(icon: HugeIcons.strokeRoundedCircle, size: 6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 14, height: 1.3),
          ),
        ),
      ],
    );
  }
}
