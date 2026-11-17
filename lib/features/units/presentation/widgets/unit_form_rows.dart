import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';

/// Minimum tap area for the small trailing actions of a row.
const double _kActionSize = 44;

/// Responsible-person row of the unit form: role icon, small role label,
/// the chosen person (or a tertiary placeholder), optional inline error and a
/// chevron. Tapping it opens the member picker.
class UnitFormRoleRow extends StatelessWidget {
  const UnitFormRoleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.placeholder,
    required this.onTap,
    this.selected,
    this.errorText,
    this.onClear,
  });

  final HugeIconData icon;

  /// Role name, already translated (Capitán, Secretario…).
  final String label;

  /// Shown in tertiary color while nothing is chosen ("Elegir miembro").
  final String placeholder;
  final ClubMember? selected;

  /// Inline error shown under the value after a submit attempt.
  final String? errorText;
  final VoidCallback? onTap;

  /// When set and a person is chosen, replaces the chevron with a clear
  /// button (optional roles only).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasValue = selected != null;
    final value = hasValue ? selected!.fullName : placeholder;

    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: HugeIcon(icon: icon, size: 17, color: c.ink600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight:
                            hasValue ? FontWeight.w600 : FontWeight.w500,
                        color: hasValue ? c.text : c.textTertiary,
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedAlert02,
                              size: 13,
                              color: c.onErrorContainer,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: TextStyle(
                                fontSize: SacFontSize.bodySmall,
                                color: c.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (hasValue && onClear != null)
                SizedBox(
                  width: _kActionSize,
                  height: _kActionSize,
                  child: IconButton(
                    tooltip: 'common.clear'.tr(),
                    onPressed: onClear,
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                      color: c.textTertiary,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First row of the members group: accent plus icon + "Agregar miembros".
class UnitFormAddMembersRow extends StatelessWidget {
  const UnitFormAddMembersRow({super.key, required this.onTap});

  /// Null disables the row (no club members to choose from).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final color = onTap == null ? c.textTertiary : accent.color;

    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: onTap == null ? c.surfaceVariant : accent.light,
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    size: 17,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'units.form.add_members'.tr(),
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Member of the unit: avatar, name and a trash button to remove it.
class UnitFormMemberRow extends StatelessWidget {
  const UnitFormMemberRow({
    super.key,
    required this.member,
    required this.onRemove,
  });

  final ClubMember member;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            SacMemberAvatar(
              imageUrl: member.avatar,
              name: member.fullName,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                member.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  fontWeight: FontWeight.w500,
                  color: c.text,
                ),
              ),
            ),
            SizedBox(
              width: _kActionSize,
              height: _kActionSize,
              child: IconButton(
                tooltip: 'units.form.remove_member'
                    .tr(namedArgs: {'name': member.fullName}),
                onPressed: onRemove,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  size: 17,
                  color: c.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Last row of the members group: "Ver los N restantes".
class UnitFormShowMoreRow extends StatelessWidget {
  const UnitFormShowMoreRow({
    super.key,
    required this.remaining,
    required this.onTap,
  });

  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          child: Text(
            'units.form.show_remaining'.tr(namedArgs: {'count': '$remaining'}),
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
