import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/member_insurance.dart';

/// Fila de miembro en la lista agrupada de seguros.
///
/// Sin card por item: highlight de press (iOS), chevron, status como texto.
class MemberInsuranceCard extends StatefulWidget {
  final MemberInsurance insurance;
  final VoidCallback? onTap;
  final bool showSeparator;

  const MemberInsuranceCard({
    super.key,
    required this.insurance,
    required this.onTap,
    this.showSeparator = true,
  });

  @override
  State<MemberInsuranceCard> createState() => _MemberInsuranceCardState();
}

class _MemberInsuranceCardState extends State<MemberInsuranceCard> {
  bool _pressed = false;

  bool get _tappable => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final insurance = widget.insurance;
    final highlight = _pressed && _tappable;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _tappable ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _tappable ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _tappable ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: ColoredBox(
        color: highlight ? c.surfaceVariant : Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: c.text,
                                    letterSpacing: -0.2,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (insurance.memberClass != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            insurance.memberClass!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: c.textSecondary,
                                      fontSize: 13,
                                    ),
                          ),
                        ],
                        if (_expiryText(insurance).isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            _expiryText(insurance),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _expiryColor(insurance),
                                      fontSize: 12,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    insurance.status.label,
                    style: TextStyle(
                      color: _statusColor(insurance.status),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  if (_tappable) ...[
                    const SizedBox(width: 4),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 14,
                      color: c.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.showSeparator)
              Padding(
                padding: const EdgeInsets.only(left: 62),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: c.borderLight,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(InsuranceStatus status) {
    final c = context.sac;
    switch (status) {
      case InsuranceStatus.asegurado:
        return c.success;
      case InsuranceStatus.vencido:
        return c.onWarning;
      case InsuranceStatus.sinSeguro:
        return c.error;
    }
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
    final c = context.sac;
    switch (m.status) {
      case InsuranceStatus.asegurado:
        final days = m.daysUntilExpiry;
        return (days != null && days <= 30) ? c.onWarning : c.textTertiary;
      case InsuranceStatus.vencido:
        return c.onWarning;
      case InsuranceStatus.sinSeguro:
        return c.textTertiary;
    }
  }
}

class _MemberAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;

  const _MemberAvatar({required this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final initials = _initials(name);

    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                memCacheWidth: 108,
                memCacheHeight: 108,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _InitialsAvatar(
                  initials: initials,
                  background: c.surfaceVariant,
                  foreground: c.textSecondary,
                ),
              )
            : _InitialsAvatar(
                initials: initials,
                background: c.surfaceVariant,
                foreground: c.textSecondary,
              ),
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
  final Color background;
  final Color foreground;

  const _InitialsAvatar({
    required this.initials,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
