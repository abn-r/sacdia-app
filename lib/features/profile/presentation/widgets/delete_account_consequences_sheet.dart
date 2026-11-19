import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/family_outcome_messages.dart';
import 'package:sacdia_app/features/family/presentation/providers/family_providers.dart';

import '../utils/delete_account_flow.dart';

/// What the user chose in the delete-account consequences sheet.
enum DeleteConsequencesChoice { download, proceed }

/// The sheet's answer. [dependentsAck] is `acknowledged` when the sheet listed
/// minors and the user continued (the list is the notice), `none` otherwise
/// (no minors, or the impact did not load: the server decides).
class DeleteConsequencesResult {
  const DeleteConsequencesResult(this.choice, this.dependentsAck);

  final DeleteConsequencesChoice choice;
  final DependentsAck dependentsAck;
}

/// "Eliminar tu cuenta" sheet shown BEFORE the delete flow: what is lost and,
/// from `deletion-impact`, what happens to each minor in your care. Offers
/// "Descargar mis datos" and the destructive "Continuar". Null when dismissed.
Future<DeleteConsequencesResult?> showDeleteConsequencesSheet(
  BuildContext context,
) {
  return showSacSheet<DeleteConsequencesResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DeleteConsequencesSheet(),
  );
}

class _DeleteConsequencesSheet extends ConsumerStatefulWidget {
  const _DeleteConsequencesSheet();

  @override
  ConsumerState<_DeleteConsequencesSheet> createState() =>
      _DeleteConsequencesSheetState();
}

class _DeleteConsequencesSheetState
    extends ConsumerState<_DeleteConsequencesSheet> {
  /// Same patience as the delete flow: past it, the impact counts as unknown
  /// and the user is not blocked.
  static const _impactTimeout = Duration(seconds: 10);

  Timer? _timeout;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(_impactTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _close(DeleteConsequencesChoice choice, List<DeletionImpactEntry> deps) {
    Navigator.of(context).pop(
      DeleteConsequencesResult(
        choice,
        choice == DeleteConsequencesChoice.proceed && deps.isNotEmpty
            ? DependentsAck.acknowledged
            : DependentsAck.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final impact = ref.watch(deletionImpactProvider);
    final dependents = impact.value ?? const <DeletionImpactEntry>[];
    final checking = impact.isLoading && !impact.hasValue && !_timedOut;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(
              title: 'settings.delete_sheet.title'.tr(),
              subtitle: 'settings.delete_sheet.subtitle'.tr(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SacSettingsGroup(
                children: [
                  _LossRow(
                    key: const ValueKey('delete-loss-profile'),
                    icon: HugeIcons.strokeRoundedUser,
                    text: 'settings.delete_sheet.loss_profile'.tr(),
                  ),
                  const SacSettingsDivider(),
                  _LossRow(
                    key: const ValueKey('delete-loss-progress'),
                    icon: HugeIcons.strokeRoundedGraduationScroll,
                    text: 'settings.delete_sheet.loss_progress'.tr(),
                  ),
                  for (final entry in dependents) ...[
                    const SacSettingsDivider(),
                    _LossRow(
                      key: ValueKey('delete-dependent-${entry.userId}'),
                      icon: HugeIcons.strokeRoundedUserGroup,
                      text: outcomeMessage(entry.outcome, entry.displayName),
                    ),
                  ],
                  if (checking) ...[
                    const SacSettingsDivider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: SacLoadingSmall(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'settings.delete_sheet.checking_dependents'.tr(),
                              style: TextStyle(
                                fontSize: SacFontSize.bodyMedium,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 10, 26, 0),
              child: Text(
                'settings.delete_sheet.download_hint'.tr(),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  color: c.textTertiary,
                  height: 1.35,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SacButton.outline(
                    key: const ValueKey('delete-sheet-download'),
                    text: 'settings.delete_sheet.download'.tr(),
                    icon: HugeIcons.strokeRoundedDownload02,
                    onPressed: () =>
                        _close(DeleteConsequencesChoice.download, dependents),
                  ),
                  const SizedBox(height: 10),
                  SacButton.destructive(
                    key: const ValueKey('delete-sheet-continue'),
                    text: 'settings.delete_sheet.continue'.tr(),
                    onPressed: checking
                        ? null
                        : () => _close(
                            DeleteConsequencesChoice.proceed, dependents),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LossRow extends StatelessWidget {
  const _LossRow({super.key, required this.icon, required this.text});

  final HugeIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            HugeIcon(icon: icon, size: 18, color: c.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: SacFontSize.titleSmall,
                  color: c.text,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
