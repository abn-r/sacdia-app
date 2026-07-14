import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_panel.dart';

/// Sólo un valor resuelto exitosamente puede abrir la frontera.
///
/// No usa `valueOrNull`: durante refresh/error Riverpod puede conservar un
/// valor anterior y ese dato obsoleto no debe sostener acciones de mutación.
bool camporeeParticipantsAreEnabled(
  AsyncValue<CamporeeSectionRegistration> registrationAsync,
) {
  if (registrationAsync.isLoading || registrationAsync.hasError) return false;
  return registrationAsync.valueOrNull?.enablesParticipants ?? false;
}

/// Frontera fail-closed para cualquier pantalla que lea o muta participantes.
///
/// El [child] sólo entra al árbol cuando el contrato de dominio habilita
/// participantes, por lo que sus providers no se observan durante loading,
/// error ni estados de inscripción bloqueados.
class CamporeeParticipantAccessGate extends StatelessWidget {
  final AsyncValue<CamporeeSectionRegistration> registrationAsync;
  final VoidCallback onRetry;
  final Widget child;

  const CamporeeParticipantAccessGate({
    super.key,
    required this.registrationAsync,
    required this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (camporeeParticipantsAreEnabled(registrationAsync)) {
      return child;
    }
    final displayAsync = registrationAsync.isLoading
        ? const AsyncLoading<CamporeeSectionRegistration>()
        : registrationAsync.hasError
            ? AsyncError<CamporeeSectionRegistration>(
                registrationAsync.error!,
                registrationAsync.stackTrace!,
              )
            : registrationAsync;
    final registration = displayAsync.valueOrNull;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CamporeeSectionRegistrationPanel(
                registrationAsync: displayAsync,
                onEnroll: _noOp,
                onRetry: onRetry,
                onManageParticipants: _noOp,
                showActions: false,
              ),
              if (registration != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'camporees.section_registration.participants_locked'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.sac.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _noOp() {}
