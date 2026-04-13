import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/investiture_pending.dart';
import '../providers/investiture_providers.dart';
import '../widgets/investiture_status_badge.dart';
import 'investiture_history_view.dart';

/// Vista para coordinadores/admins: lista de enrollments pendientes de validación.
///
/// Requiere GlobalRolesGuard (admin, coordinator) en el backend.
/// Cada ítem muestra nombre del miembro, clase, fecha de envío
/// y botones de Aprobar / Rechazar.
class InvestiturePendingListView extends ConsumerWidget {
  const InvestiturePendingListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingInvestituresProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Validación de Investidura'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(pendingInvestituresProvider),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 22,
            ),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: pendingAsync.when(
          data: (list) => _buildList(context, ref, list, hPad, c),
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _buildError(context, ref, error),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<InvestiturePending> list,
    double hPad,
    SacColors c,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
              size: 56,
              color: c.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay investiduras pendientes',
              style: TextStyle(fontSize: 16, color: c.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Todas las validaciones están al día',
              style: TextStyle(fontSize: 13, color: c.textTertiary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(pendingInvestituresProvider),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
        itemCount: list.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAward01,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${list.length} pendiente${list.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          return _PendingCard(item: list[index - 1]);
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final c = context.sac;
    final msg = error.toString().replaceFirst('Exception: ', '');
    // 403 significa que el usuario no tiene permiso
    final is403 = msg.contains('permiso') || msg.contains('403');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: is403
                  ? HugeIcons.strokeRoundedLockKey
                  : HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              is403
                  ? 'Acceso restringido'
                  : 'Error al cargar investiduras pendientes',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              is403
                  ? 'Solo coordinadores y administradores pueden acceder a esta sección.'
                  : msg,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (!is403) ...[
              const SizedBox(height: 24),
              SacButton.primary(
                text: 'Reintentar',
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: () => ref.invalidate(pendingInvestituresProvider),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Pending Card ──────────────────────────────────────────────────────────────

class _PendingCard extends ConsumerWidget {
  final InvestiturePending item;

  const _PendingCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final validateState =
        ref.watch(validateEnrollmentNotifierProvider(item.enrollmentId));
    final markState =
        ref.watch(markAsInvestidoNotifierProvider(item.enrollmentId));

    final isLoading = validateState.isLoading || markState.isLoading;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: avatar + nombre + badge ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: item.fullName, photoUrl: item.userPhotoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fullName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                    ),
                    if (item.className != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.className!,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                    if (item.clubName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.clubName!,
                        style: TextStyle(fontSize: 11, color: c.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InvestitureStatusBadge(status: item.status),
            ],
          ),

          const SizedBox(height: 10),

          // ── Fecha de envío ────────────────────────────────────────────────
          if (item.submittedAt != null)
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  size: 13,
                  color: c.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Enviado el ${DateFormat('dd/MM/yyyy').format(item.submittedAt!.toLocal())}',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),

          // ── Comentario del director ───────────────────────────────────────
          if (item.comments != null && item.comments!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${item.comments}"',
                style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Acciones ──────────────────────────────────────────────────────
          if (isLoading)
            const Center(
              child: SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            _buildActions(context, ref),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Ver historial
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InvestitureHistoryView(enrollmentId: item.enrollmentId),
                ),
              );
            },
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              size: 16,
            ),
            label: const Text('Historial'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Rechazar
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRejectDialog(context, ref),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 16,
              color: AppColors.error,
            ),
            label: Text(
              'Rechazar',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Aprobar
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showApproveDialog(context, ref),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
              size: 16,
              color: Colors.white,
            ),
            label: const Text('Aprobar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showApproveDialog(BuildContext context, WidgetRef ref) async {
    final commentsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar investidura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Confirmas la aprobación de ${item.fullName}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comentarios (opcional)',
                hintText: 'Ej: Cumplió todos los requisitos',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final notifier =
        ref.read(validateEnrollmentNotifierProvider(item.enrollmentId).notifier);
    final ok = await notifier.approve(
      comments: commentsCtrl.text.trim().isEmpty
          ? null
          : commentsCtrl.text.trim(),
    );

    if (!context.mounted) return;
    _showSnackbar(
      context,
      ok ? 'Investidura aprobada correctamente' : 'Error al aprobar',
      ok ? AppColors.secondary : AppColors.error,
    );
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref) async {
    final commentsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar investidura'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Rechazás la investidura de ${item.fullName}?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: commentsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo del rechazo *',
                  hintText: 'Es obligatorio indicar el motivo',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'El motivo es obligatorio'
                        : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final notifier =
        ref.read(validateEnrollmentNotifierProvider(item.enrollmentId).notifier);
    final ok = await notifier.reject(comments: commentsCtrl.text.trim());

    if (!context.mounted) return;
    _showSnackbar(
      context,
      ok ? 'Investidura rechazada' : 'Error al rechazar',
      ok ? AppColors.accent : AppColors.error,
    );
  }

  void _showSnackbar(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _Avatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
