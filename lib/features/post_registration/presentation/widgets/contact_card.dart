import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../data/models/emergency_contact_model.dart';

/// Card que muestra un contacto de emergencia con opciones de edición y eliminación.
class ContactCard extends StatelessWidget {
  final EmergencyContactModel contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ContactCard({
    super.key,
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final initials = _initialsFor(contact.name);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: context.sac.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ContactAvatar(initials: initials, color: primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          contact.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: context.sac.text,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (contact.primary) ...[
                        const SizedBox(width: 8),
                        _PrimaryBadge(color: primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (contact.relationshipTypeName != null &&
                      contact.relationshipTypeName!.trim().isNotEmpty) ...[
                    Text(
                      contact.relationshipTypeName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.sac.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCall,
                        size: 16,
                        color: context.sac.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          contact.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.sac.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _ActionPill(
                        icon: HugeIcons.strokeRoundedEdit02,
                        label: 'common.edit'.tr(),
                        color: primary,
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 8),
                      _ActionPill(
                        icon: HugeIcons.strokeRoundedDelete02,
                        label: 'common.delete'.tr(),
                        color: context.sac.error,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$second'.toUpperCase();
  }
}

class _ContactAvatar extends StatelessWidget {
  final String initials;
  final Color color;

  const _ContactAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -10,
            bottom: -12,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Text(
            initials,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  final Color color;

  const _PrimaryBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'post_registration.contact_form.primary_title'.tr(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SacButton(
        text: label,
        icon: icon,
        onPressed: onPressed,
        variant: SacButtonVariant.outline,
        fullWidth: true,
        size: SacButtonSize.small,
        textColor: color,
        borderColor: color.withValues(alpha: 0.22),
        backgroundColor: color.withValues(alpha: 0.04),
        iconSize: 17,
        fontSize: 13,
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}
