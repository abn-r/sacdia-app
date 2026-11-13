import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../majority_release_error_messages.dart';
import '../providers/majority_release_providers.dart';
import 'adult_claim_code_sheet.dart';

/// Acción del director en la ficha de un miembro liberado al cumplir la mayoría
/// de edad (Fase 4): «Generar código de acceso» para quien no tiene
/// credenciales y venía bajo custodia del club.
///
/// Solo se ofrece a quien tiene `club_members:approve` (el servidor lo exige);
/// el servidor responde 404 si la persona no cumple (tiene cuenta, no está
/// liberada o no es de custodia). El código se muestra una sola vez.
class DirectorAdultClaimRow extends ConsumerStatefulWidget {
  const DirectorAdultClaimRow({
    super.key,
    required this.clubSectionId,
    required this.dependentUserId,
    required this.dependentName,
  });

  final int clubSectionId;
  final String dependentUserId;
  final String dependentName;

  @override
  ConsumerState<DirectorAdultClaimRow> createState() =>
      _DirectorAdultClaimRowState();
}

class _DirectorAdultClaimRowState extends ConsumerState<DirectorAdultClaimRow> {
  bool _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    final result =
        await ref.read(majorityReleaseRepositoryProvider).issueDirectorCode(
              clubSectionId: widget.clubSectionId,
              dependentUserId: widget.dependentUserId,
            );
    if (!mounted) return;
    setState(() => _busy = false);
    await result.fold<Future<void>>(
      (failure) async => SacSnackBar.show(
        context,
        majorityReleaseErrorMessage(failure),
        isError: true,
      ),
      (issued) => showAdultClaimCodeSheet(
        context,
        issued: issued,
        personName: widget.dependentName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return SacCard(
      key: const ValueKey('director_adult_claim_row'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'adult_claim.director.title'.tr(),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'adult_claim.director.hint'.tr(),
            style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 12),
          SacButton.outline(
            key: const ValueKey('director_adult_claim_generate'),
            text: 'adult_claim.director.generate'.tr(),
            icon: HugeIcons.strokeRoundedKey01,
            isLoading: _busy,
            isEnabled: !_busy,
            onPressed: _generate,
          ),
        ],
      ),
    );
  }
}
