import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/acting_for_session.dart';
import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/consent/consent_evidence_uploader.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../family/presentation/providers/family_providers.dart';

/// Alcance que el servidor concede solo a un tutor actuando (`consent:evidence`).
const String kConsentEvidenceScope = 'consent:evidence';

/// ¿Debe el paso 3 ofrecer subir la ficha firmada del menor?
///
/// Solo mientras un tutor actúa por él, el consentimiento no está verificado y
/// el servidor concedió el alcance `consent:evidence` en `/auth/me`. Sin ese
/// alcance (servidor anterior, perfil de otro tipo) no se ofrece: el rodeo de
/// la Fase 2 sigue siendo subirla desde Mi familia.
bool canUploadConsentWhileActing(
  UserEntity? user, {
  required ActingDependent? acting,
}) {
  final info = user?.actingFor;
  if (info == null || acting == null) return false;
  if (info.dependentUserId != acting.userId) return false;
  if (info.consentStatus == 'verified') return false;
  return info.scopes.contains(kConsentEvidenceScope);
}

/// Subir la ficha de consentimiento firmada desde el paso 3 del post-registro,
/// actuando por el menor (FP3-27).
///
/// La subida va a la ruta de "actuar por" (`X-Acting-For`) y no a la de Mi
/// familia. Subirla NUNCA verifica nada: el director lo hace. Cualquier fallo
/// se explica por su `code` (ya verificada, almacén no disponible, archivo
/// inválido...) dentro del propio selector.
class ActingConsentFormCard extends ConsumerStatefulWidget {
  const ActingConsentFormCard({
    super.key,
    this.picker = const ConsentEvidencePicker(),
  });

  /// Inyectable para probar sin los plugins de cámara/archivos.
  final ConsentEvidencePicker picker;

  @override
  ConsumerState<ActingConsentFormCard> createState() =>
      _ActingConsentFormCardState();
}

class _ActingConsentFormCardState extends ConsumerState<ActingConsentFormCard> {
  bool _uploaded = false;

  @override
  Widget build(BuildContext context) {
    final acting = ref.watch(actingDependentProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (!canUploadConsentWhileActing(user, acting: acting)) {
      return const SizedBox.shrink();
    }
    final dependent = acting!;
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SacCard(
        key: const ValueKey('acting_consent_form_card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'family.detail.form_title'.tr(),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _uploaded
                  ? 'family.detail.consent_form_uploaded'.tr()
                  : 'family.detail.form_hint'.tr(),
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            ConsentEvidenceUploader(
              picker: widget.picker,
              hasExisting: _uploaded,
              onUpload: (file) => ref
                  .read(familyActionsProvider)
                  .uploadConsentEvidenceWhileActing(dependent.userId, file),
              onUploaded: (ConsentEvidenceReceipt receipt) {
                if (!mounted) return;
                setState(() => _uploaded = true);
                SacSnackBar.show(
                  context,
                  'family.detail.form_uploaded_toast'.tr(),
                );
              },
              // El director verificó mientras tanto: `/auth/me` se vuelve a
              // pedir y la tarjeta desaparece sola.
              onAlreadyVerified: () {},
            ),
          ],
        ),
      ),
    );
  }
}
