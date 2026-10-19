import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/family_outcome_messages.dart';

/// Aviso previo a borrar la cuenta de un tutor con menores a cargo (FP-66).
///
/// Lista qué pasará con cada menor (otro tutor / custodia del club / congelado
/// y borrado a los 90 días) y exige marcar una casilla antes de poder
/// continuar. Los datos salen de `GET /guardianships/me/deletion-impact`; nunca
/// del `details` del 409 (el backend lo omite en producción).
///
/// Se cierra con `true` si el tutor acepta y `false`/`null` si cancela.
class DeleteAccountDependentsDialog extends StatefulWidget {
  const DeleteAccountDependentsDialog({super.key, required this.dependents});

  final List<DeletionImpactEntry> dependents;

  @override
  State<DeleteAccountDependentsDialog> createState() =>
      _DeleteAccountDependentsDialogState();
}

class _DeleteAccountDependentsDialogState
    extends State<DeleteAccountDependentsDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacDialog(
      title: 'settings.delete_account.dependents.title'.tr(),
      icon: HugeIcons.strokeRoundedAlert02,
      iconColor: AppColors.error,
      iconBackgroundColor: AppColors.errorLight,
      content: 'settings.delete_account.dependents.intro'.tr(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in widget.dependents)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedUser,
                              size: 16,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              outcomeMessage(entry.outcome, entry.displayName),
                              style: TextStyle(
                                fontSize: 14,
                                color: c.text,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => setState(() => _acknowledged = !_acknowledged),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Checkbox(
                  value: _acknowledged,
                  onChanged: (v) => setState(() => _acknowledged = v ?? false),
                ),
                Expanded(
                  child: Text(
                    'settings.delete_account.dependents.ack'.tr(),
                    style: TextStyle(fontSize: 14, color: c.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        SacDialogAction(
          label: 'common.cancel'.tr(),
          onPressed: () => Navigator.of(context).pop(false),
          style: SacDialogActionStyle.cancel,
        ),
        SacDialogAction(
          label: 'settings.delete_account.dependents.continue'.tr(),
          onPressed:
              _acknowledged ? () => Navigator.of(context).pop(true) : null,
          style: SacDialogActionStyle.destructive,
        ),
      ],
    );
  }
}
