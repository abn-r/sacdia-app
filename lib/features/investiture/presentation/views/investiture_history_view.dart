import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/investiture_history_entry.dart';
import '../providers/investiture_providers.dart';

/// Vista de historial de acciones de investidura para un enrollment.
///
/// Muestra una línea de tiempo con todas las acciones realizadas:
/// quién envió, quién aprobó/rechazó y cuándo ocurrió cada paso.
///
/// Accesible para cualquier usuario autenticado (JwtAuthGuard).
class InvestitureHistoryView extends ConsumerWidget {
  final int enrollmentId;

  const InvestitureHistoryView({super.key, required this.enrollmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(investitureHistoryProvider(enrollmentId));
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Historial de Investidura'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.invalidate(investitureHistoryProvider(enrollmentId)),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 22,
            ),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: historyAsync.when(
          data: (history) => _buildTimeline(context, history, hPad, c),
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _buildError(context, ref, error),
        ),
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    List<InvestitureHistoryEntry> history,
    double hPad,
    SacColors c,
  ) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              size: 56,
              color: c.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin historial registrado',
              style: TextStyle(fontSize: 16, color: c.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[index];
        final isLast = index == history.length - 1;
        return _TimelineEntry(entry: entry, isLast: isLast);
      },
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final c = context.sac;
    final msg = error.toString().replaceFirst('Exception: ', '');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar historial',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: () =>
                  ref.invalidate(investitureHistoryProvider(enrollmentId)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Timeline Entry ────────────────────────────────────────────────────────────

class _TimelineEntry extends StatelessWidget {
  final InvestitureHistoryEntry entry;
  final bool isLast;

  const _TimelineEntry({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final color = _actionColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Línea de tiempo ──────────────────────────────────────────────
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Punto del evento
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: HugeIcon(icon: _icon, size: 16, color: color),
                ),
                // Línea conectora
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: c.border,
                      margin: const EdgeInsets.only(top: 4),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Contenido del evento ─────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título de la acción
                  Text(
                    entry.action.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 2),
                  // Ejecutor
                  Text(
                    entry.performerFullName,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (entry.performerRole != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      entry.performerRole!,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Fecha
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendar01,
                        size: 12,
                        color: c.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(entry.performedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  // Comentarios
                  if (entry.comments != null &&
                      entry.comments!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        '"${entry.comments}"',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
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

  Color get _actionColor {
    switch (entry.action) {
      case InvestitureAction.submitted:
        return AppColors.accentDark;
      case InvestitureAction.approved:
        return AppColors.statusInfoText;
      case InvestitureAction.rejected:
        return AppColors.error;
      case InvestitureAction.invested:
        return AppColors.secondary;
    }
  }

  List<List<dynamic>> get _icon {
    switch (entry.action) {
      case InvestitureAction.submitted:
        return HugeIcons.strokeRoundedSent;
      case InvestitureAction.approved:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case InvestitureAction.rejected:
        return HugeIcons.strokeRoundedCancel01;
      case InvestitureAction.invested:
        return HugeIcons.strokeRoundedAward01;
    }
  }
}
