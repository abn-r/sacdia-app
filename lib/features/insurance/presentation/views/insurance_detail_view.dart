import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/member_insurance.dart';
import '../providers/insurance_providers.dart';
import '../widgets/insurance_status_badge.dart';
import 'insurance_form_sheet.dart';

/// Pantalla de detalle completo del seguro de un miembro.
class InsuranceDetailView extends ConsumerWidget {
  final MemberInsurance insurance;

  const InsuranceDetailView({super.key, required this.insurance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManageAsync = ref.watch(canManageInsuranceProvider);
    final canManage = canManageAsync.valueOrNull ?? false;

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        backgroundColor: context.sac.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Detalle del Seguro',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
        ),
        centerTitle: false,
        actions: [
          if (canManage)
            IconButton(
              onPressed: () => _openEdit(context),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                size: 22,
                color: context.sac.textSecondary,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member header card
            _MemberHeaderCard(insurance: insurance),

            const SizedBox(height: 16),

            // Insurance status (big badge)
            _StatusSection(insurance: insurance),

            const SizedBox(height: 16),

            // Policy details
            if (insurance.insuranceId != null) ...[
              _InfoCard(
                title: 'Datos del seguro',
                icon: HugeIcons.strokeRoundedFiles01,
                children: [
                  if (insurance.insuranceType != null)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedTag01,
                      label: 'Tipo de seguro',
                      value: insurance.insuranceType!.label,
                    ),
                  if (insurance.policyNumber != null &&
                      insurance.policyNumber!.isNotEmpty)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedId,
                      label: 'N. de póliza / folio',
                      value: insurance.policyNumber!,
                    ),
                  if (insurance.providerName != null &&
                      insurance.providerName!.isNotEmpty)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedBuilding01,
                      label: 'Aseguradora',
                      value: insurance.providerName!,
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Coverage period
              _InfoCard(
                title: 'Período de cobertura',
                icon: HugeIcons.strokeRoundedCalendar01,
                children: [
                  if (insurance.startDate != null)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedCalendarAdd01,
                      label: 'Inicio de cobertura',
                      value: DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es')
                          .format(insurance.startDate!),
                    ),
                  if (insurance.endDate != null)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedCalendarRemove01,
                      label: 'Fin de cobertura',
                      value: DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es')
                          .format(insurance.endDate!),
                    ),
                  if (insurance.coverageAmount != null)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedMoney01,
                      label: 'Monto de cobertura / prima',
                      value: '\$${insurance.coverageAmount!.toStringAsFixed(2)}',
                      valueColor: AppColors.secondary,
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Evidence file
              _EvidenceSection(insurance: insurance),

              const SizedBox(height: 12),

              // Audit trail
              _InfoCard(
                title: 'Auditoría',
                icon: HugeIcons.strokeRoundedUserCheck01,
                children: [
                  if (insurance.registeredByName != null)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedUser,
                      label: 'Registrado por',
                      value: insurance.registeredAt != null
                          ? '${insurance.registeredByName!} · ${DateFormat('dd/MM/yyyy').format(insurance.registeredAt!)}'
                          : insurance.registeredByName!,
                    ),
                  if (insurance.modifiedByName != null)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedEdit01,
                      label: 'Última modificación',
                      value: insurance.modifiedAt != null
                          ? '${insurance.modifiedByName!} · ${DateFormat('dd/MM/yyyy').format(insurance.modifiedAt!)}'
                          : insurance.modifiedByName!,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InsuranceFormSheet(
        preselectedMemberId: insurance.memberId,
        existingInsurance: insurance,
      ),
    );
  }
}

// ── Member header ──────────────────────────────────────────────────────────────

class _MemberHeaderCard extends StatelessWidget {
  final MemberInsurance insurance;

  const _MemberHeaderCard({required this.insurance});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(insurance.memberName);
    final statusColor = _statusColor(insurance.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: statusColor.withValues(alpha: 0.4), width: 2),
                ),
                child: ClipOval(
                  child: insurance.memberPhotoUrl != null &&
                          insurance.memberPhotoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: insurance.memberPhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator.adaptive()),
                          errorWidget: (context, url, error) =>
                              _AvatarFallback(initials: initials, color: statusColor),
                        )
                      : _AvatarFallback(initials: initials, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insurance.memberName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.sac.text,
                      ),
                ),
                if (insurance.memberClass != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      insurance.memberClass!,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(InsuranceStatus s) {
    switch (s) {
      case InsuranceStatus.asegurado:
        return AppColors.secondary;
      case InsuranceStatus.vencido:
        return AppColors.accent;
      case InsuranceStatus.sinSeguro:
        return AppColors.error;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  final Color color;

  const _AvatarFallback({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

// ── Status section ─────────────────────────────────────────────────────────────

class _StatusSection extends StatelessWidget {
  final MemberInsurance insurance;

  const _StatusSection({required this.insurance});

  @override
  Widget build(BuildContext context) {
    final days = insurance.daysUntilExpiry;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado del seguro',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          InsuranceStatusBadge(status: insurance.status, large: true),
          if (days != null) ...[
            const SizedBox(height: 8),
            Text(
              _vigenciaText(insurance.status, days),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _vigenciaColor(insurance.status, days),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _vigenciaText(InsuranceStatus status, int days) {
    switch (status) {
      case InsuranceStatus.asegurado:
        if (days == 0) return 'Vence hoy';
        return 'Vigente por $days días más';
      case InsuranceStatus.vencido:
        final overdue = days.abs();
        return 'Venció hace $overdue día${overdue != 1 ? 's' : ''}';
      case InsuranceStatus.sinSeguro:
        return '';
    }
  }

  Color _vigenciaColor(InsuranceStatus status, int days) {
    switch (status) {
      case InsuranceStatus.asegurado:
        return days <= 30 ? AppColors.accentDark : AppColors.secondaryDark;
      case InsuranceStatus.vencido:
        return AppColors.errorDark;
      case InsuranceStatus.sinSeguro:
        return AppColors.errorDark;
    }
  }
}

// ── Evidence section ───────────────────────────────────────────────────────────

class _EvidenceSection extends StatelessWidget {
  final MemberInsurance insurance;

  const _EvidenceSection({required this.insurance});

  @override
  Widget build(BuildContext context) {
    final hasEvidence = insurance.evidenceFileUrl != null &&
        insurance.evidenceFileUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAttachment,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  'Evidencia de pago',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.sac.text,
                      ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: hasEvidence
                ? _EvidencePreview(insurance: insurance)
                : _NoEvidence(),
          ),
        ],
      ),
    );
  }
}

class _EvidencePreview extends StatelessWidget {
  final MemberInsurance insurance;

  const _EvidencePreview({required this.insurance});

  bool get _isPdf {
    final url = insurance.evidenceFileUrl ?? '';
    final name = insurance.evidenceFileName ?? '';
    return url.toLowerCase().contains('.pdf') ||
        name.toLowerCase().endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_isPdf) {
      return _PdfTile(
        fileName: insurance.evidenceFileName ?? 'Comprobante',
        fileUrl: insurance.evidenceFileUrl!,
      );
    }

    // Image preview
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: insurance.evidenceFileUrl!,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator.adaptive()),
            errorWidget: (context, url, error) => Container(
              height: 100,
              color: AppColors.primarySurface,
              child: const Center(
                child: Text(
                  'No se pudo cargar la imagen',
                  style: TextStyle(color: AppColors.primaryDark),
                ),
              ),
            ),
          ),
        ),
        if (insurance.evidenceFileName != null) ...[
          const SizedBox(height: 8),
          Text(
            insurance.evidenceFileName!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _PdfTile extends StatelessWidget {
  final String fileName;
  final String fileUrl;

  const _PdfTile({required this.fileName, required this.fileUrl});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openUrl(fileUrl),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedFiles01,
              size: 32,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primaryDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Toca para abrir',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedDownload01,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _NoEvidence extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedFile01,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 12),
        Text(
          'Sin evidencia de pago adjunta',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ── Info card ──────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final List<List<dynamic>> icon;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                HugeIcon(
                  icon: icon,
                  size: 18,
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Divider(
              height: 1, thickness: 0.5, indent: 16, endIndent: 16),
          // Rows with dividers between them
          ...List.generate(children.length * 2 - 1, (i) {
            if (i.isOdd) {
              return Divider(
                height: 1,
                thickness: 0.5,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context)
                    .dividerColor
                    .withValues(alpha: 0.5),
              );
            }
            return children[i ~/ 2];
          }),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: valueColor,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
