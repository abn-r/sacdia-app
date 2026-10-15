import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/user_honor.dart';
import '../providers/honors_providers.dart';

enum _HonorMenuAction { abandon }

/// Top bar overflow menu for an enrolled honor with the "leave honor" action.
///
/// Renders nothing when the honor can no longer be abandoned (under review or
/// approved). On success it shows feedback and, when [popOnSuccess] is true,
/// closes the current work screen since the enrollment no longer exists.
class HonorAbandonMenuButton extends ConsumerWidget {
  final UserHonor userHonor;
  final String honorName;
  final bool popOnSuccess;

  const HonorAbandonMenuButton({
    super.key,
    required this.userHonor,
    required this.honorName,
    this.popOnSuccess = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!userHonor.canAbandon) return const SizedBox.shrink();

    final c = context.sac;
    final isLoading = ref.watch(
      honorAbandonActionsNotifierProvider.select((s) => s.isLoading),
    );

    return PopupMenuButton<_HonorMenuAction>(
      key: const ValueKey('honor-abandon-menu'),
      tooltip: 'honors.abandon.menu_tooltip'.tr(),
      enabled: !isLoading,
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedMoreHorizontal,
        size: 20,
        color: c.textSecondary,
      ),
      onSelected: (action) {
        switch (action) {
          case _HonorMenuAction.abandon:
            _confirmAndAbandon(context, ref);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<_HonorMenuAction>(
          value: _HonorMenuAction.abandon,
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedLogout03,
                size: 18,
                color: c.error,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'honors.abandon.action'.tr(),
                  style: TextStyle(color: c.error, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndAbandon(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    // Abandoning invalidates the enrollment, so the screen hosting this button
    // rebuilds without it. Feedback and navigation go through the navigator,
    // which outlives this widget.
    final navigator = Navigator.of(context);
    final notifier = ref.read(honorAbandonActionsNotifierProvider.notifier);

    final confirmed = await SacDialog.show(
      context,
      title: 'honors.abandon.confirm_title'.tr(),
      content:
          'honors.abandon.confirm_message'.tr(namedArgs: {'name': honorName}),
      confirmLabel: 'honors.abandon.confirm_cta'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    final user = ref.read(authNotifierProvider).valueOrNull ??
        await ref.read(authNotifierProvider.future);
    if (!navigator.mounted) return;

    final userId = user?.id;
    if (userId == null) {
      SacSnackBar.show(navigator.context, 'honors.abandon.no_session'.tr(),
          isError: true);
      return;
    }

    final success =
        await notifier.abandon(userId: userId, honorId: userHonor.honorId);
    if (!navigator.mounted) return;

    SacSnackBar.show(
      navigator.context,
      success ? 'honors.abandon.success'.tr() : 'honors.abandon.error'.tr(),
      isError: !success,
    );

    // Navigator.pop skips PopScope guards (unsaved checklist edits no longer
    // matter once the enrollment is gone).
    if (success && popOnSuccess && navigator.canPop()) {
      navigator.pop();
    }
  }
}
