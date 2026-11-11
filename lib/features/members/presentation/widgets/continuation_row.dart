import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/annual_continuation.dart';

/// Class name and logo shown after «Clase sugerida:».
class ContinuationClassInfo {
  const ContinuationClassInfo({required this.name, this.logoAsset});

  final String name;
  final String? logoAsset;
}

/// Human reason a member can't be enrolled (`blocked_reasons.*`).
String continuationBlockedLabel(AnnualContinuation item) {
  final code = item.blockedReason ?? item.suggestedClass.code;
  if (code == null || code.isEmpty) {
    return tr('members.continuations.blocked');
  }
  final key = 'members.continuations.blocked_reasons.$code';
  final translated = tr(key);
  return translated == key ? code : translated;
}

/// Row of «Listos para inscribir»: avatar, name, role · suggested class and a
/// trailing checkbox. The whole row toggles the selection.
class ContinuationSelectableRow extends StatelessWidget {
  const ContinuationSelectableRow({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onToggle,
    this.classInfo,
  });

  final AnnualContinuation item;
  final bool isSelected;
  final VoidCallback onToggle;
  final ContinuationClassInfo? classInfo;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    // `current_role` llega como slug (`deputy-director`); se muestra traducido.
    final role = RoleUtils.translate((item.currentRole ?? '').trim());
    final subtitle = _subtitle(context, role, classInfo, c.textSecondary);

    return Semantics(
      checked: isSelected,
      enabled: true,
      onTap: onToggle,
      child: MergeSemantics(
        child: SacPressable(
          onTap: onToggle,
          semanticButton: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SacMemberAvatar(name: item.name, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _RowText(name: item.name, subtitle: subtitle)),
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: _Checkbox(
                      key: ValueKey('continuation-checkbox-${item.userId}'),
                      isSelected: isSelected,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _subtitle(
    BuildContext context,
    String role,
    ContinuationClassInfo? info,
    Color color,
  ) {
    final style = TextStyle(
      fontSize: SacFontSize.bodySmall,
      color: color,
      height: 1.2,
    );
    final roleText = role.isEmpty
        ? null
        : tr('members.continuations.current_role', namedArgs: {'role': role});
    if (info == null) {
      return roleText == null
          ? null
          : Text(
              roleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            );
    }
    final logo = info.logoAsset;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          // Next to the class, the bare role is enough («Subdirector ·»).
          if (role.isNotEmpty) TextSpan(text: '$role · '),
          TextSpan(
              text: '${tr('members.continuations.suggested_class_label')} '),
          if (logo != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ExcludeSemantics(
                  child: Image.asset(
                    logo,
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    cacheWidth: 54,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 18),
                  ),
                ),
              ),
            ),
          TextSpan(text: info.name),
        ],
      ),
      // Two lines so the suggested class is never cut off.
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Row of «No se pueden inscribir»: not tappable, shows the reason and a chip.
class ContinuationBlockedRow extends StatelessWidget {
  const ContinuationBlockedRow({super.key, required this.item});

  final AnnualContinuation item;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reason = Text(
      continuationBlockedLabel(item),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: SacFontSize.bodySmall,
        color: c.textSecondary,
        height: 1.2,
      ),
    );

    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SacMemberAvatar(name: item.name, size: 40),
              const SizedBox(width: 12),
              Expanded(child: _RowText(name: item.name, subtitle: reason)),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.warningContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(
                    tr('members.continuations.blocked'),
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight: FontWeight.w600,
                      color: c.onWarningContainer,
                    ),
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

class _RowText extends StatelessWidget {
  const _RowText({required this.name, required this.subtitle});

  final String name;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: SacFontSize.titleSmall,
            fontWeight: FontWeight.w600,
            color: c.text,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          subtitle!,
        ],
      ],
    );
  }
}

/// 24pt box: accent fill and `onColor` check when selected, `border` outline
/// otherwise. The row is the 44pt+ hit target.
class _Checkbox extends StatelessWidget {
  const _Checkbox({super.key, required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? accent.color : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius2XS + 2),
        border: Border.all(
          color: isSelected ? accent.color : c.border,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: isSelected
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedTick02,
              size: 16,
              color: accent.onColor,
            )
          : null,
    );
  }
}
