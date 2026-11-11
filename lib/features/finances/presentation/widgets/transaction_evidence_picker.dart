import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/transaction.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Selector de evidencias (máx. 3) del formulario de movimiento: muestra las
/// ya subidas, las nuevas por subir y el botón para agregar otra.
class TransactionEvidencePicker extends StatelessWidget {
  final List<FinanceEvidence> existingEvidences;
  final List<XFile> newFiles;
  final String? errorText;
  final VoidCallback onAdd;
  final ValueChanged<XFile> onRemoveNew;

  const TransactionEvidencePicker({
    super.key,
    required this.existingEvidences,
    required this.newFiles,
    required this.onAdd,
    required this.onRemoveNew,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final total = existingEvidences.length + newFiles.length;
    final canAdd = total < 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'finances.add_transaction.evidence_hint'.tr(),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.sac.textSecondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...existingEvidences.map(
              (evidence) => _EvidenceTile.network(evidence.url),
            ),
            ...newFiles.map(
              (file) =>
                  _EvidenceTile.file(file, onRemove: () => onRemoveNew(file)),
            ),
            if (canAdd) _EvidenceAddTile(onTap: onAdd),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'finances.add_transaction.evidence_count'.tr(
            namedArgs: {'count': total.toString()},
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.sac.textTertiary),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.sac.error),
          ),
        ],
      ],
    );
  }
}

class _EvidenceAddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _EvidenceAddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SacInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Ink(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: SacAccent.of(context).color.withValues(alpha: 0.35),
            ),
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 28,
              color: SacAccent.of(context).color,
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  final String? url;
  final XFile? file;
  final VoidCallback? onRemove;

  const _EvidenceTile.network(this.url)
      : file = null,
        onRemove = null;

  const _EvidenceTile.file(this.file, {required this.onRemove}) : url = null;

  @override
  Widget build(BuildContext context) {
    final image = file != null
        ? Image.file(
            File(file!.path),
            fit: BoxFit.cover,
            cacheWidth: 276,
            cacheHeight: 276,
          )
        : Image.network(
            url!,
            fit: BoxFit.cover,
            cacheWidth: 276,
            cacheHeight: 276,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Stack(
        children: [
          SizedBox(width: 92, height: 92, child: image),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: context.sac.barrierColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 14,
                      color: context.sac.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
