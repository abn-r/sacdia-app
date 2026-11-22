import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_settings.dart';
import '../../../../core/widgets/sac_sheet.dart';

/// What the ⋯ menu of a certification can do.
enum CertificationMenuAction { about, leave }

/// Surface of every sheet of the certification screens.
Widget _sheetSurface(BuildContext context, Widget child) {
  return Container(
    decoration: BoxDecoration(
      color: context.sac.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusLG),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: child,
      ),
    ),
  );
}

Future<T?> _showSurface<T>(
  BuildContext context,
  Widget Function(BuildContext) builder,
) {
  return showSacSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _sheetSurface(ctx, builder(ctx)),
  );
}

/// ⋯ of the certification screen: «Acerca de esta certificación» and, last
/// and in red, «Dejar la certificación» (only while it can be left).
Future<CertificationMenuAction?> showCertificationMenuSheet(
  BuildContext context, {
  required bool canLeave,
}) {
  return _showSurface<CertificationMenuAction>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SacSheetHeader(title: 'certifications.view.title'.tr()),
        SacSettingsGroup(
          children: [
            SacSettingsTile(
              key: const ValueKey('certification-menu-about'),
              icon: HugeIcons.strokeRoundedInformationCircle,
              title: 'certifications.view.menu_about'.tr(),
              onTap: () => Navigator.of(ctx).pop(CertificationMenuAction.about),
            ),
            if (canLeave) ...[
              const SacSettingsDivider(),
              SacSettingsTile(
                key: const ValueKey('certification-menu-leave'),
                icon: HugeIcons.strokeRoundedLogout01,
                title: 'certifications.view.menu_leave'.tr(),
                destructive: true,
                onTap: () =>
                    Navigator.of(ctx).pop(CertificationMenuAction.leave),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

/// The full description of a certification.
Future<void> showCertificationAboutSheet(
  BuildContext context, {
  required String name,
  String? description,
}) {
  final text = description?.trim() ?? '';
  return _showSurface<void>(
    context,
    (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: 'certifications.view.about_title'.tr(),
            subtitle: name,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                text.isEmpty ? 'certifications.view.about_empty'.tr() : text,
                key: const ValueKey('certification-about-text'),
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  height: 1.5,
                  color: text.isEmpty ? ctx.sac.textSecondary : ctx.sac.text,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Confirmation of the enrollment, in the accent (it is a good action, not a
/// red one). Resolves to true when the person confirms.
Future<bool> showCertificationEnrollSheet(
  BuildContext context, {
  required String name,
}) async {
  final result = await _showSurface<bool>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacSheetHeader(
          title: 'certifications.view.enroll_title'.tr(),
          subtitle: name,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
          child: Text(
            'certifications.view.enroll_body'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.titleMedium,
              height: 1.45,
              color: ctx.sac.textSecondary,
            ),
          ),
        ),
        SacButton.primary(
          key: const ValueKey('certification-enroll-confirm'),
          text: 'certifications.view.enroll_confirm'.tr(),
          icon: HugeIcons.strokeRoundedCertificate01,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        const SizedBox(height: 8),
        SacButton.ghost(
          text: 'certifications.view.cancel'.tr(),
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Confirmation of leaving a certification (destructive, in the sheet).
Future<bool> showCertificationLeaveSheet(
  BuildContext context, {
  required String name,
}) async {
  final result = await _showSurface<bool>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacSheetHeader(
          title: 'certifications.view.leave_title'.tr(),
          subtitle: name,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
          child: Text(
            'certifications.view.leave_body'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.titleMedium,
              height: 1.45,
              color: ctx.sac.textSecondary,
            ),
          ),
        ),
        SacButton.destructive(
          key: const ValueKey('certification-leave-confirm'),
          text: 'certifications.view.leave_confirm'.tr(),
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        const SizedBox(height: 8),
        SacButton.ghost(
          text: 'certifications.view.cancel'.tr(),
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ],
    ),
  );
  return result ?? false;
}
