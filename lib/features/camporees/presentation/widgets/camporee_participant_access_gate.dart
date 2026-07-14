import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
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

/// Autoridad exacta para mutar participantes del Camporí.
///
/// La inscripción habilita la lectura. La mutación además exige que el
/// `activeGrant` canónico sea el director activo de la misma sección CLUB.
/// Los roles globales o asignaciones históricas nunca participan del cálculo.
bool canRegisterCamporeeParticipants(
  AsyncValue<CamporeeSectionRegistration> registrationAsync,
  AsyncValue<UserEntity?> authAsync,
) {
  if (!camporeeParticipantsAreEnabled(registrationAsync) ||
      authAsync.isLoading ||
      authAsync.hasError) {
    return false;
  }

  final registration = registrationAsync.valueOrNull;
  final authorization = authAsync.valueOrNull?.authorization;
  final activeGrant = authorization?.activeGrant;
  if (registration == null ||
      activeGrant == null ||
      !activeGrant.isActive ||
      activeGrant.roleName?.trim().toLowerCase() != ClubRoleNames.director) {
    return false;
  }

  // `activeGrant` sólo se resuelve desde clubAssignments (scope CLUB). Además
  // se exige la identidad completa de la sección que devolvió el backend.
  return activeGrant.assignmentId != null &&
      activeGrant.assignmentId == authorization!.activeAssignmentId &&
      activeGrant.clubId == registration.clubId &&
      activeGrant.sectionId == registration.clubSectionId &&
      activeGrant.clubTypeId == registration.clubTypeId;
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

/// Frontera de mutación: combina inscripción elegible y autoridad del actor.
class CamporeeParticipantRegistrationGate extends StatelessWidget {
  final AsyncValue<CamporeeSectionRegistration> registrationAsync;
  final AsyncValue<UserEntity?> authAsync;
  final VoidCallback onRetryRegistration;
  final VoidCallback onRetryAuth;
  final Widget child;

  const CamporeeParticipantRegistrationGate({
    super.key,
    required this.registrationAsync,
    required this.authAsync,
    required this.onRetryRegistration,
    required this.onRetryAuth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!camporeeParticipantsAreEnabled(registrationAsync)) {
      return CamporeeParticipantAccessGate(
        registrationAsync: registrationAsync,
        onRetry: onRetryRegistration,
        child: child,
      );
    }

    if (canRegisterCamporeeParticipants(registrationAsync, authAsync)) {
      return child;
    }

    if (authAsync.isLoading) {
      return const _ParticipantAuthorityState(loading: true);
    }
    if (authAsync.hasError) {
      return _ParticipantAuthorityState(onRetry: onRetryAuth);
    }
    return const _ParticipantAuthorityState();
  }
}

class _ParticipantAuthorityState extends StatelessWidget {
  final bool loading;
  final VoidCallback? onRetry;

  const _ParticipantAuthorityState({
    this.loading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.sac;
    final isError = onRetry != null;
    final title = isError
        ? 'camporees.section_registration.load_error'.tr()
        : loading
            ? 'camporees.section_registration.loading'.tr()
            : 'camporees.section_registration.states.read_only.title'.tr();
    final description = isError
        ? 'camporees.section_registration.load_error_hint'.tr()
        : 'camporees.section_registration.states.read_only.description'.tr();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Semantics(
          container: true,
          liveRegion: loading || isError,
          label: title,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520, minHeight: 220),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loading) ...[
                  const Center(child: SacLoading()),
                  const SizedBox(height: 20),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.45,
                      ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label:
                        'camporees.section_registration.retry_semantics'.tr(),
                    child: SacButton.outline(
                      text: 'camporees.section_registration.retry'.tr(),
                      icon: HugeIcons.strokeRoundedRefresh,
                      onPressed: onRetry,
                      textColor: colors.text,
                      borderColor: colors.textSecondary,
                      labelMaxLines: 2,
                      labelOverflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _noOp() {}
