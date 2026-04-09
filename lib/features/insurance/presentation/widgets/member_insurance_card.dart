import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/member_insurance.dart';
import 'insurance_status_badge.dart';

/// Tarjeta de miembro con su estado de seguro.
///
/// Al tocar, navega a la pantalla de detalle (si asegurado/vencido)
/// o abre el formulario de registro (si sin seguro y con permisos).
class MemberInsuranceCard extends StatelessWidget {
  final MemberInsurance insurance;
  final VoidCallback onTap;
  final bool canManage;

  const MemberInsuranceCard({
    super.key,
    required this.insurance,
    required this.onTap,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _borderColor().withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.sac.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              _MemberAvatar(
                photoUrl: insurance.memberPhotoUrl,
                name: insurance.memberName,
                status: insurance.status,
              ),

              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      insurance.memberName,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.sac.text,
                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (insurance.memberClass != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        insurance.memberClass!,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.sac.textSecondary,
                                  fontSize: 11,
                                ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    // Badge + expiry date
                    Row(
                      children: [
                        InsuranceStatusBadge(
                            status: insurance.status, compact: true),
                        if (insurance.endDate != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _expiryText(insurance),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: _expiryColor(insurance.status),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right action indicator
              _RightIndicator(
                status: insurance.status,
                canManage: canManage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _borderColor() {
    switch (insurance.status) {
      case InsuranceStatus.asegurado:
        return AppColors.secondary;
      case InsuranceStatus.vencido:
        return AppColors.accent;
      case InsuranceStatus.sinSeguro:
        return AppColors.error;
    }
  }

  String _expiryText(MemberInsurance m) {
    if (m.endDate == null) return '';
    final formatted = DateFormat('dd/MM/yyyy').format(m.endDate!.toLocal());
    switch (m.status) {
      case InsuranceStatus.asegurado:
        final days = m.daysUntilExpiry;
        if (days != null && days <= 30) {
          return 'Vence en $days días';
        }
        return 'Vigente hasta $formatted';
      case InsuranceStatus.vencido:
        final overdue = DateTime.now().difference(m.endDate!).inDays;
        return 'Venció hace $overdue días';
      case InsuranceStatus.sinSeguro:
        return '';
    }
  }

  Color _expiryColor(InsuranceStatus status) {
    switch (status) {
      case InsuranceStatus.asegurado:
        final days = insurance.daysUntilExpiry;
        return (days != null && days <= 30)
            ? AppColors.accentDark
            : AppColors.secondaryDark;
      case InsuranceStatus.vencido:
        return AppColors.accentDark;
      case InsuranceStatus.sinSeguro:
        return AppColors.errorDark;
    }
  }
}

// ── Avatar ───────────────────────────────────────────────────────────────────────

class _MemberAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final InsuranceStatus status;

  const _MemberAvatar({
    required this.photoUrl,
    required this.name,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final statusColor = _statusColor(status);

    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 2),
          ),
          child: ClipOval(
            child: photoUrl != null && photoUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photoUrl!,
                    memCacheWidth: 144,  // 48 * 3 (max device pixel ratio)
                    memCacheHeight: 144, // 48 * 3
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _InitialsAvatar(
                        initials: initials, color: statusColor),
                  )
                : _InitialsAvatar(initials: initials, color: statusColor),
          ),
        ),
        // Status dot
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: context.sac.surface, width: 1.5),
            ),
          ),
        ),
      ],
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

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;

  const _InitialsAvatar({required this.initials, required this.color});

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
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ── Right indicator ──────────────────────────────────────────────────────────────

class _RightIndicator extends StatelessWidget {
  final InsuranceStatus status;
  final bool canManage;

  const _RightIndicator({required this.status, required this.canManage});

  @override
  Widget build(BuildContext context) {
    if (status == InsuranceStatus.sinSeguro && canManage) {
      // Add button for uninsured members
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Registrar',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    // Arrow for insured/expired members
    return HugeIcon(
      icon: HugeIcons.strokeRoundedArrowRight01,
      size: 18,
      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );
  }
}
