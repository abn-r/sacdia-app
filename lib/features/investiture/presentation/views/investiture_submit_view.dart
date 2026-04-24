import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/investiture_member.dart';
import '../../domain/entities/investiture_status.dart';
import '../providers/investiture_providers.dart';
import '../widgets/investiture_status_badge.dart';
import 'investiture_history_view.dart';

/// Vista para directores/consejeros: enviar un enrollment a validación.
///
/// Recibe la lista de miembros de la sección con sus estados de investidura
/// actuales y permite al director/consejero seleccionar un miembro
/// y enviar su enrollment para validación.
///
/// [clubId] es requerido para la llamada al backend.
/// [members] es la lista de miembros de la sección con sus estados.
class InvestitureSubmitView extends ConsumerWidget {
  final int clubId;
  final List<InvestitureMember> members;

  const InvestitureSubmitView({
    super.key,
    required this.clubId,
    required this.members,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    // Solo se muestran los miembros que pueden ser enviados a validación:
    // - IN_PROGRESS (primera vez)
    // - REJECTED (re-envío después de rechazo)
    final submittable = members
        .where((m) =>
            m.investitureStatus == InvestitureStatus.inProgress ||
            m.investitureStatus == InvestitureStatus.rejected)
        .toList();

    final alreadySent = members
        .where((m) =>
            m.investitureStatus != InvestitureStatus.inProgress &&
            m.investitureStatus != InvestitureStatus.rejected)
        .toList();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('investiture.submit.title'.tr()),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          children: [
            // ── Banner informativo ────────────────────────────────────────
            _InfoBanner(),
            const SizedBox(height: 16),

            // ── Miembros disponibles para envío ──────────────────────────
            if (submittable.isNotEmpty) ...[
              Text(
                'investiture.submit.section_available'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
              ),
              const SizedBox(height: 8),
              ...submittable.map(
                (member) => _MemberSubmitCard(
                  member: member,
                  clubId: clubId,
                ),
              ),
            ],

            // ── Miembros en otros estados ─────────────────────────────────
            if (alreadySent.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'investiture.submit.section_status'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
              ),
              const SizedBox(height: 8),
              ...alreadySent.map(
                (member) => _MemberStatusCard(member: member),
              ),
            ],

            // ── Sin miembros ──────────────────────────────────────────────
            if (members.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserGroup,
                      size: 56,
                      color: c.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'investiture.submit.empty'.tr(),
                      style: TextStyle(fontSize: 16, color: c.textSecondary),
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

// ── Info Banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 18,
            color: AppColors.accentDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'investiture.submit.info_banner'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.accentDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Member Submit Card ────────────────────────────────────────────────────────

class _MemberSubmitCard extends ConsumerWidget {
  final InvestitureMember member;
  final int clubId;

  const _MemberSubmitCard({required this.member, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final submitState =
        ref.watch(submitForValidationNotifierProvider(member.enrollmentId));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          _Avatar(name: member.fullName, photoUrl: member.userPhotoUrl),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                ),
                if (member.className != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.className!,
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
                const SizedBox(height: 6),
                InvestitureStatusBadge(status: member.investitureStatus),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Botón enviar
          submitState.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : ElevatedButton(
                  onPressed: () => _showSubmitDialog(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text('investiture.submit.btn_send'.tr()),
                ),
        ],
      ),
    );
  }

  Future<void> _showSubmitDialog(BuildContext context, WidgetRef ref) async {
    final commentsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('investiture.submit.dialog_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'investiture.submit.dialog_body'
                  .tr(namedArgs: {'name': member.fullName}),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentsCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'investiture.submit.field_comments_label'.tr(),
                hintText: 'investiture.submit.field_comments_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('investiture.submit.btn_send'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(
        submitForValidationNotifierProvider(member.enrollmentId).notifier);
    final ok = await notifier.submit(
      clubId: clubId,
      comments: commentsCtrl.text.trim().isEmpty
          ? null
          : commentsCtrl.text.trim(),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'investiture.submit.snack_sent'.tr()
              : 'investiture.submit.snack_send_error'.tr(),
        ),
        backgroundColor: ok ? AppColors.secondary : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Member Status Card ────────────────────────────────────────────────────────

class _MemberStatusCard extends StatelessWidget {
  final InvestitureMember member;

  const _MemberStatusCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _Avatar(name: member.fullName, photoUrl: member.userPhotoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                ),
                if (member.className != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.className!,
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
                const SizedBox(height: 6),
                InvestitureStatusBadge(status: member.investitureStatus),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Ver historial
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvestitureHistoryView(
                    enrollmentId: member.enrollmentId,
                  ),
                ),
              );
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              size: 20,
              color: c.textSecondary,
            ),
            tooltip: 'investiture.submit.tooltip_history'.tr(),
          ),
        ],
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
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    final theme = Theme.of(context);
    final fallback = Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: (photoUrl != null && photoUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 80,
                memCacheHeight: 80,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}

// ── SacLoading placeholder (re-export convenience) ────────────────────────────
// ignore: unused_element
class _LoadingCenter extends StatelessWidget {
  const _LoadingCenter();

  @override
  Widget build(BuildContext context) => const Center(child: SacLoading());
}
