import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_settings.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_text_field.dart';

/// What the "more" menu of an order can do.
enum OrderMenuAction { copyFolio, cancel }

/// The "more" menu as a sheet: the harmless options first, cancelling last
/// and red. Resolves to the chosen action, null when dismissed.
Future<OrderMenuAction?> showOrderMenuSheet(
  BuildContext context, {
  required bool canCopyFolio,
  required bool canCancel,
}) {
  return showSacSheet<OrderMenuAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = ctx.sac;
      return Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLG),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SacSheetHeader(title: 'materials.order.menu_title'.tr()),
                SacSettingsGroup(
                  children: [
                    if (canCopyFolio)
                      SacSettingsTile(
                        key: const ValueKey('order-menu-copy'),
                        icon: HugeIcons.strokeRoundedCopy01,
                        title: 'materials.order.copy_folio'.tr(),
                        onTap: () =>
                            Navigator.of(ctx).pop(OrderMenuAction.copyFolio),
                      ),
                    if (canCopyFolio && canCancel) const SacSettingsDivider(),
                    if (canCancel)
                      SacSettingsTile(
                        key: const ValueKey('order-menu-cancel'),
                        icon: HugeIcons.strokeRoundedCancelCircle,
                        title: 'materials.order.cancel'.tr(),
                        destructive: true,
                        onTap: () =>
                            Navigator.of(ctx).pop(OrderMenuAction.cancel),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Asks the reason and confirms the cancellation. Resolves to the reason when
/// confirmed, null otherwise. The error shows next to the field.
Future<String?> showCancelOrderSheet(
  BuildContext context, {
  required String folio,
}) {
  return showSacSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CancelOrderSheet(folio: folio),
  );
}

class _CancelOrderSheet extends StatefulWidget {
  const _CancelOrderSheet({required this.folio});

  final String folio;

  @override
  State<_CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<_CancelOrderSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'materials.order.reason_required'.tr());
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLG),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SacSheetGrabber(),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(
                    'materials.order.cancel_title'.tr(),
                    style: TextStyle(
                      fontSize: SacFontSize.titleLarge,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'materials.order.cancel_body'
                      .tr(namedArgs: {'folio': widget.folio}),
                  style: TextStyle(
                    fontSize: SacFontSize.titleSmall,
                    height: 1.45,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SacTextField(
                  key: const ValueKey('cancel-reason'),
                  controller: _controller,
                  label: 'materials.order.reason_label'.tr(),
                  maxLines: 2,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      _error!,
                      key: const ValueKey('cancel-reason-error'),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.onErrorContainer,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SacButton.destructive(
                  key: const ValueKey('cancel-confirm'),
                  text: 'materials.order.cancel'.tr(),
                  icon: HugeIcons.strokeRoundedCancelCircle,
                  onPressed: _confirm,
                ),
                const SizedBox(height: 8),
                SacButton.outline(
                  text: 'common.back'.tr(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
