import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/validation.dart';
import '../providers/validation_providers.dart';
import 'validation_status_badge.dart';

/// Sección de validación que se embebe en la vista de detalle de clase u honor.
///
/// Muestra:
///  - Badge del estado actual (del último historial o inProgress si vacío)
///  - Botón "Enviar a revisión" (solo si no está pendingReview / approved)
///  - Timeline del historial de validaciones
class ValidationSection extends ConsumerWidget {
  final ValidationEntityType entityType;
  final int entityId;

  const ValidationSection({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (entityType: entityType, entityId: entityId);
    final historyAsync = ref.watch(validationHistoryProvider(key));
    final submitState = ref.watch(submitValidationProvider);
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(
          children: [
            Text(
              'VALIDACIÓN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            historyAsync.whenOrNull(
              data: (history) {
                if (history.isEmpty) return null;
                final latest = history.first;
                return ValidationStatusBadge(status: latest.status);
              },
            ) ??
                const ValidationStatusBadge(status: ValidationStatus.inProgress),
          ],
        ),

        const SizedBox(height: 12),

        // ── Submit button ────────────────────────────────────────────────
        historyAsync.when(
          loading: () => const SizedBox(height: 40, child: Center(child: SacLoading())),
          error: (_, __) => const SizedBox.shrink(),
          data: (history) {
            final latestStatus = history.isEmpty
                ? ValidationStatus.inProgress
                : history.first.status;

            final canSubmit = latestStatus == ValidationStatus.inProgress ||
                latestStatus == ValidationStatus.rejected;

            if (!canSubmit) return const SizedBox.shrink();

            return SacButton.primary(
              text: 'Enviar a revisión',
              icon: HugeIcons.strokeRoundedSent,
              isLoading: submitState.isLoading,
              onPressed: submitState.isLoading
                  ? null
                  : () => _submit(context, ref),
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Error message ────────────────────────────────────────────────
        if (submitState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    color: AppColors.error,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      submitState.errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── History timeline ─────────────────────────────────────────────
        historyAsync.when(
          loading: () => const SizedBox(height: 60, child: Center(child: SacLoading())),
          error: (e, _) => Text(
            'No se pudo cargar el historial',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          data: (history) {
            if (history.isEmpty) {
              return Text(
                'Sin historial de validaciones',
                style: TextStyle(fontSize: 13, color: c.textTertiary),
              );
            }

            return Column(
              children: history
                  .asMap()
                  .entries
                  .map(
                    (e) => _HistoryItem(
                      entry: e.value,
                      isLast: e.key == history.length - 1,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(submitValidationProvider.notifier);
    final success = await notifier.submit(
      entityType: entityType,
      entityId: entityId,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enviado a revisión correctamente'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

// ── Timeline item ─────────────────────────────────────────────────────────────

class _HistoryItem extends StatelessWidget {
  final ValidationHistoryEntry entry;
  final bool isLast;

  const _HistoryItem({required this.entry, required this.isLast});

  Color _dotColor() {
    switch (entry.status) {
      case ValidationStatus.approved:
        return AppColors.secondary;
      case ValidationStatus.rejected:
        return AppColors.error;
      case ValidationStatus.pendingReview:
        return AppColors.accent;
      case ValidationStatus.inProgress:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(entry.createdAt.toLocal());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline line + dot ────────────────────────────────────
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: _dotColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: c.border,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Content ────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ValidationStatusBadge(status: entry.status),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: c.textTertiary),
                      ),
                    ],
                  ),
                  if (entry.reviewerName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Revisor: ${entry.reviewerName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                  if (entry.reviewerComment != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.reviewerComment!,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
