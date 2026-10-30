import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../family/presentation/family_error_messages.dart';
import '../../domain/entities/claim_code.dart';
import '../../domain/usecases/issue_claim_code.dart';
import '../providers/members_providers.dart';

/// "Entregar a la familia": el director genera el código de un solo uso (7 días)
/// con el que la familia de un menor bajo custodia del club lo reclama desde
/// Mi familia (FP3-63/64). Cierra el pendiente A15 de la Fase 2.
///
/// Solo se ofrece a quien tiene `club_members:approve` (el servidor lo exige) y
/// para un menor sin tutor vinculado. El código se muestra en memoria: no se
/// guarda en ningún lado.
class ClaimCodeSection extends ConsumerStatefulWidget {
  const ClaimCodeSection({
    super.key,
    required this.clubSectionId,
    required this.dependentUserId,
    required this.dependentName,
  });

  final int clubSectionId;
  final String dependentUserId;

  /// Nombre de pila (o completo) para el mensaje que se comparte.
  final String dependentName;

  @override
  ConsumerState<ClaimCodeSection> createState() => _ClaimCodeSectionState();
}

class _ClaimCodeSectionState extends ConsumerState<ClaimCodeSection> {
  bool _busy = false;

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    SacSnackBar.show(context, message, isError: isError);
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    final result = await ref.read(issueClaimCodeUseCaseProvider)(
      IssueClaimCodeParams(
        clubSectionId: widget.clubSectionId,
        dependentUserId: widget.dependentUserId,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      // Solo el `code` de negocio; el texto crudo del servidor no se muestra.
      (failure) => _toast(familyErrorMessage(failure), isError: true),
      _showCode,
    );
  }

  Future<void> _showCode(IssuedClaimCode issued) {
    final expires = DateFormat.yMMMd(context.locale.toString())
        .add_jm()
        .format(issued.expiresAt.toLocal());
    final message = 'members.claim_code.share_message'.tr(namedArgs: {
      'name': widget.dependentName,
      'code': issued.code,
      'when': expires,
    });

    return SacDialog.present<void>(
      context,
      builder: (dialogContext) => SacDialog(
        title: 'members.claim_code.code_title'.tr(),
        icon: HugeIcons.strokeRoundedKey01,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              issued.code,
              style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: dialogContext.sac.text,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'members.claim_code.expires'.tr(namedArgs: {'when': expires}),
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: dialogContext.sac.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SacDialogAction(
            label: 'members.claim_code.copy'.tr(),
            style: SacDialogActionStyle.cancel,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: issued.code));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _toast('members.claim_code.copied'.tr());
            },
          ),
          SacDialogAction(
            label: 'members.claim_code.share'.tr(),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await SharePlus.instance.share(ShareParams(text: message));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'members.claim_code.section_title'.tr(),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'members.claim_code.hint'.tr(),
            style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 12),
          SacButton.outline(
            text: 'members.claim_code.action'.tr(),
            icon: HugeIcons.strokeRoundedKey01,
            // A 402pt la etiqueta no cabe en una línea (en fr/pt-BR menos aún):
            // se parte en dos en vez de cortarse con «…».
            labelMaxLines: 2,
            isLoading: _busy,
            onPressed: _busy ? null : _generate,
          ),
        ],
      ),
    );
  }
}
