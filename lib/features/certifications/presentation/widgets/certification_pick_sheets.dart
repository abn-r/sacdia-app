import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../honors/domain/entities/user_honor.dart';
import '../../../honors/presentation/providers/honors_providers.dart';
import '../../domain/entities/certification_activity_option.dart';
import '../providers/certification_requirement_providers.dart';

/// One row of a picker: icon tile, title and an optional second line. With
/// [accent] it is the action row («Elegir actividad»).
class CertificationPickRow extends StatelessWidget {
  const CertificationPickRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.detail,
    this.accent = false,
    this.selected = false,
  });

  final HugeIconData icon;
  final String title;
  final String? detail;
  final VoidCallback? onTap;
  final bool accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accentColor = SacAccent.of(context).color;
    final detail = this.detail;
    final tint = accent ? accentColor : c.textSecondary;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent
                    ? accentColor.withValues(alpha: 0.12)
                    : c.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              child: HugeIcon(icon: icon, size: 17, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: accent ? accentColor : c.text,
                    ),
                  ),
                  if (detail != null && detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                size: 18,
                color: c.success,
              )
            else if (onTap != null && !accent)
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: c.textTertiary,
              ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      enabled: onTap != null,
      excludeSemantics: true,
      selected: selected,
      onTap: onTap,
      label:
          [title, if (detail != null && detail.isNotEmpty) detail].join('. '),
      child: onTap == null
          ? Opacity(opacity: 0.5, child: content)
          : SacInkWell(
              onTap: onTap,
              pressedScale: SacMotion.rowPressScale,
              child: content,
            ),
    );
  }
}

String formatActivityDetail(CertificationActivityOption option) {
  final date = option.activityDate;
  return [
    if (date != null) DateFormat('d MMM y').format(date.toLocal()),
    if ((option.clubName ?? '').isNotEmpty) option.clubName!,
  ].join(' · ');
}

/// Shared chrome of the pickers.
Future<T?> _showPickerSheet<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  return showSacSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: ctx.sac.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
          ),
          child: builder(ctx),
        ),
      ),
    ),
  );
}

/// Picks one of the activities the server offers for a component.
Future<CertificationActivityOption?> showCertificationActivitySheet(
  BuildContext context, {
  required CertificationActivityOptionsQuery query,
  int? selectedId,
}) {
  return _showPickerSheet<CertificationActivityOption>(
    context,
    (ctx) => _ActivitySheet(query: query, selectedId: selectedId),
  );
}

class _ActivitySheet extends ConsumerWidget {
  const _ActivitySheet({required this.query, this.selectedId});

  final CertificationActivityOptionsQuery query;
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(certificationActivityOptionsProvider(query));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacSheetHeader(title: 'certifications.req.activity_sheet_title'.tr()),
        Flexible(
          child: options.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: SacLoading()),
            ),
            error: (error, _) => _SheetMessage(
              text: userErrorMessage(error),
              onRetry: () =>
                  ref.invalidate(certificationActivityOptionsProvider(query)),
            ),
            data: (list) => list.isEmpty
                ? _SheetMessage(
                    text: 'certifications.req.activity_empty'.tr(),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: list.length,
                    itemBuilder: (context, i) => CertificationPickRow(
                      key: ValueKey(
                          'certification-activity-${list[i].activityId}'),
                      icon: HugeIcons.strokeRoundedCalendar03,
                      title: list[i].name,
                      detail: formatActivityDetail(list[i]),
                      selected: list[i].activityId == selectedId,
                      onTap: () => Navigator.of(context).pop(list[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Picks one of the user's approved honors.
Future<UserHonor?> showCertificationHonorSheet(
  BuildContext context, {
  int? selectedId,
}) {
  return _showPickerSheet<UserHonor>(
    context,
    (ctx) => _HonorSheet(selectedId: selectedId),
  );
}

class _HonorSheet extends ConsumerWidget {
  const _HonorSheet({this.selectedId});

  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honors = ref.watch(userHonorsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacSheetHeader(title: 'certifications.req.honor_sheet_title'.tr()),
        Flexible(
          child: honors.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: SacLoading()),
            ),
            error: (error, _) => _SheetMessage(
              text: userErrorMessage(error),
              onRetry: () => ref.invalidate(userHonorsProvider),
            ),
            data: (all) {
              final approved = [
                for (final h in all)
                  if (h.isCompleted) h,
              ];
              if (approved.isEmpty) {
                return _SheetMessage(
                  text: 'certifications.req.honor_empty'.tr(),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: approved.length,
                itemBuilder: (context, i) => CertificationPickRow(
                  key: ValueKey('certification-honor-${approved[i].id}'),
                  icon: HugeIcons.strokeRoundedAward01,
                  title: approved[i].honorName ?? '#${approved[i].honorId}',
                  detail: approved[i].honorCategoryName,
                  selected: approved[i].id == selectedId,
                  onTap: () => Navigator.of(context).pop(approved[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.4,
              color: context.sac.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SacButton.outline(
              text: 'common.retry'.tr(),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
