import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/member_insurance.dart';
import 'insurance_status_badge.dart';

/// Tarjeta de miembro con estado de seguro.
/// Status solo vía badge (sin border tint + shadow + avatar dot).
class MemberInsuranceCard extends StatefulWidget {
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
  State<MemberInsuranceCard> createState() => _MemberInsuranceCardState();
}

class _MemberInsuranceCardState extends State<MemberInsuranceCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final insurance = widget.insurance;
    final reduce = SacMotion.reduceMotionOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? 0.985 : 1,
          duration: SacMotion.press,
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border.withValues(alpha: 0.75)),
            ),
            child: Row(
              children: [
                _MemberAvatar(
                  photoUrl: insurance.memberPhotoUrl,
                  name: insurance.memberName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insurance.memberName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
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
                                    color: c.textSecondary,
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          InsuranceStatusBadge(
                            status: insurance.status,
                            compact: true,
                          ),
                          if (insurance.endDate != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _expiryText(insurance),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: _expiryColor(insurance),
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
                _RightIndicator(
                  status: insurance.status,
                  canManage: widget.canManage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _expiryText(MemberInsurance m) {
    if (m.endDate == null) return '';
    final formatted = DateFormat('dd/MM/yyyy').format(m.endDate!.toLocal());
    switch (m.status) {
      case InsuranceStatus.asegurado:
        final days = m.daysUntilExpiry;
        if (days != null && days <= 30) {
          final key = days == 1
              ? 'insurance.card.expires_in_one'
              : 'insurance.card.expires_in_other';
          return key.tr(namedArgs: {'days': '$days'});
        }
        return 'insurance.card.valid_until'.tr(namedArgs: {'date': formatted});
      case InsuranceStatus.vencido:
        final overdue = DateTime.now().difference(m.endDate!).inDays;
        final key = overdue == 1
            ? 'insurance.card.expired_since_one'
            : 'insurance.card.expired_since_other';
        return key.tr(namedArgs: {'days': '$overdue'});
      case InsuranceStatus.sinSeguro:
        return '';
    }
  }

  Color _expiryColor(MemberInsurance m) {
    switch (m.status) {
      case InsuranceStatus.asegurado:
        final days = m.daysUntilExpiry;
        return (days != null && days <= 30)
            ? AppColors.accentDark
            : context.sac.textTertiary;
      case InsuranceStatus.vencido:
        return AppColors.accentDark;
      case InsuranceStatus.sinSeguro:
        return context.sac.textTertiary;
    }
  }
}

class _MemberAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;

  const _MemberAvatar({
    required this.photoUrl,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final initials = _initials(name);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.border.withValues(alpha: 0.8)),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                memCacheWidth: 132,
                memCacheHeight: 132,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _InitialsAvatar(initials: initials),
              )
            : _InitialsAvatar(initials: initials),
      ),
    );
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

  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.10),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _RightIndicator extends StatelessWidget {
  final InsuranceStatus status;
  final bool canManage;

  const _RightIndicator({required this.status, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    if (status == InsuranceStatus.sinSeguro && canManage) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'insurance.card.register_button'.tr(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return HugeIcon(
      icon: HugeIcons.strokeRoundedArrowRight01,
      size: 16,
      color: c.textTertiary,
    );
  }
}
