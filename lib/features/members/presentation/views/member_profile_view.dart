import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/info_section.dart';

import '../../domain/entities/club_member.dart';
import '../providers/members_providers.dart';

import '../../../classes/domain/entities/progressive_class.dart';
import '../../../honors/domain/entities/user_honor.dart';

/// Vista de perfil de miembro (solo lectura).
///
/// Recibe un [ClubMember] con los datos básicos de la lista y carga en segundo
/// plano el detalle completo vía [memberDetailProvider]. Si el usuario tiene
/// permiso de salud, también muestra la sección médica.
class MemberProfileView extends ConsumerWidget {
  final ClubMember member;
  final String? title;

  const MemberProfileView({
    super.key,
    required this.member,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);

    final detailAsync = ref.watch(memberDetailProvider(member.userId));
    final authUser = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );

    final canViewMedical = canByPermissionOrLegacyRole(
      authUser,
      requiredPermissions: const {'health:read', 'users:read_detail'},
      legacyRoles: const {
        'director',
        'deputy_director',
        'secretary',
        'treasurer',
        'counselor',
      },
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title ?? 'Perfil del miembro',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedLockKey,
                  color: c.textTertiary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'Solo lectura',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: detailAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _ErrorState(message: error.toString()),
          data: (fullDetail) => _ProfileScrollBody(
            detail: fullDetail,
            hPad: hPad,
            canViewMedical: canViewMedical,
          ),
        ),
      ),
    );
  }
}

// ── Scroll body ───────────────────────────────────────────────────────────────

class _ProfileScrollBody extends StatelessWidget {
  final ClubMember detail;
  final double hPad;
  final bool canViewMedical;

  const _ProfileScrollBody({
    required this.detail,
    required this.hPad,
    required this.canViewMedical,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          _MemberProfileHeader(member: detail),

          const SizedBox(height: 24),

          _PersonalInfoSection(detail: detail),

          const SizedBox(height: 20),

          _ClubInfoSection(detail: detail),

          const SizedBox(height: 20),
          _ClassesSection(userId: detail.userId),

          const SizedBox(height: 20),
          _SpecialtiesSection(userId: detail.userId),

          if (canViewMedical) ...[
            const SizedBox(height: 20),
            _MedicalInfoSection(userId: detail.userId),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Personal info section ─────────────────────────────────────────────────────

class _PersonalInfoSection extends StatelessWidget {
  final ClubMember detail;

  const _PersonalInfoSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    return InfoSection(
      title: 'Información Personal',
      items: [
        InfoItem(
          icon: HugeIcons.strokeRoundedUser,
          label: 'Nombre completo',
          value: detail.fullName,
        ),
        if (detail.email != null)
          InfoItem(
            icon: HugeIcons.strokeRoundedMail01,
            label: 'Correo electrónico',
            value: detail.email,
          ),
        if (detail.phone != null)
          InfoItem(
            icon: HugeIcons.strokeRoundedCall,
            label: 'Teléfono',
            value: detail.phone,
          ),
        if (detail.birthDate != null)
          InfoItem(
            icon: HugeIcons.strokeRoundedBirthdayCake,
            label: 'Fecha de nacimiento',
            value: DateFormat('dd/MM/yyyy').format(detail.birthDate!),
          ),
        if (detail.gender != null)
          InfoItem(
            icon: HugeIcons.strokeRoundedUser,
            label: 'Género',
            value: detail.gender,
          ),
        if (detail.address != null && detail.address!.isNotEmpty)
          InfoItem(
            icon: HugeIcons.strokeRoundedLocation01,
            label: 'Dirección',
            value: detail.address,
          ),
        if (detail.blood != null && detail.blood!.isNotEmpty)
          InfoItem(
            icon: HugeIcons.strokeRoundedBlood,
            label: 'Grupo sanguíneo',
            value: detail.blood,
          ),
      ],
    );
  }
}

// ── Club info section ─────────────────────────────────────────────────────────

class _ClubInfoSection extends StatelessWidget {
  final ClubMember detail;

  const _ClubInfoSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    String? baptismValue;
    if (detail.baptism == true) {
      if (detail.baptismDate != null) {
        baptismValue =
            'Sí · ${DateFormat('dd/MM/yyyy').format(detail.baptismDate!)}';
      } else {
        baptismValue = 'Sí';
      }
    } else if (detail.baptism == false) {
      baptismValue = 'No';
    }

    return InfoSection(
      title: 'Información del Club',
      items: [
        if (detail.clubRole != null)
          InfoItem(
            icon: HugeIcons.strokeRoundedLabel,
            label: 'Cargo en el club',
            value:
                RoleUtils.translate(detail.clubRole, gender: detail.gender),
          ),
        if (detail.currentClass != null)
          InfoItem(
            icon: HugeIcons.strokeRoundedSchool,
            label: 'Clase progresiva',
            value: detail.currentClass,
          ),
        InfoItem(
          icon: HugeIcons.strokeRoundedTicketStar,
          label: 'Estado de inscripción',
          value: detail.isEnrolled ? 'Inscrito' : 'No inscrito',
        ),
        if (baptismValue != null)
          InfoItem(
            icon: HugeIcons.strokeRoundedWaterEnergy,
            label: 'Bautizado',
            value: baptismValue,
          ),
      ],
    );
  }
}

// ── Classes section ───────────────────────────────────────────────────────────

class _ClassesSection extends ConsumerWidget {
  final String userId;

  const _ClassesSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _MedicalCard(
      icon: HugeIcons.strokeRoundedSchool,
      title: 'Clases Progresivas',
      iconColor: AppColors.sacBlue,
      child: _ClassesSectionBody(userId: userId),
    );
  }
}

class _ClassesSectionBody extends ConsumerWidget {
  final String userId;

  const _ClassesSectionBody({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memberClassesProvider(userId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SacLoadingSmall(),
      ),
      error: (e, _) => _MedicalError(
        onRetry: () => ref.invalidate(memberClassesProvider(userId)),
      ),
      data: (classes) {
        if (classes.isEmpty) {
          return _EmptyLabel('Sin clases registradas');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: classes.map((c) => _ClassItem(progressiveClass: c)).toList(),
        );
      },
    );
  }
}

class _ClassItem extends StatelessWidget {
  final ProgressiveClass progressiveClass;

  const _ClassItem({required this.progressiveClass});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final classColor = AppColors.classColor(progressiveClass.name);
    final logoAsset = AppColors.classLogoAsset(progressiveClass.name);
    final progress = progressiveClass.overallProgress;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: classColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: logoAsset != null
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(logoAsset, fit: BoxFit.contain),
                  )
                : Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedSchool,
                      color: classColor,
                      size: 18,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progressiveClass.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                if (progress != null)
                  Text(
                    'Progreso: $progress%',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (progressiveClass.investitureStatus != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _investitureColor(progressiveClass.investitureStatus!)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _investitureLabel(progressiveClass.investitureStatus!),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _investitureColor(progressiveClass.investitureStatus!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _investitureColor(String status) {
    switch (status.toUpperCase()) {
      case 'INVESTIDO':
        return AppColors.secondary;
      case 'PENDIENTE':
        return AppColors.accent;
      default:
        return AppColors.sacBlue;
    }
  }

  String _investitureLabel(String status) {
    switch (status.toUpperCase()) {
      case 'INVESTIDO':
        return 'Investido';
      case 'PENDIENTE':
        return 'Pendiente';
      default:
        return status;
    }
  }
}

// ── Specialties section ────────────────────────────────────────────────────────

class _SpecialtiesSection extends ConsumerWidget {
  final String userId;

  const _SpecialtiesSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _MedicalCard(
      icon: HugeIcons.strokeRoundedMedal01,
      title: 'Especialidades',
      iconColor: AppColors.accent,
      child: _SpecialtiesSectionBody(userId: userId),
    );
  }
}

class _SpecialtiesSectionBody extends ConsumerWidget {
  final String userId;

  const _SpecialtiesSectionBody({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memberHonorsProvider(userId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SacLoadingSmall(),
      ),
      error: (e, _) => _MedicalError(
        onRetry: () => ref.invalidate(memberHonorsProvider(userId)),
      ),
      data: (honors) {
        if (honors.isEmpty) {
          return _EmptyLabel('Sin especialidades registradas');
        }

        final validated = honors.where((h) => h.isCompleted).toList();
        final inProgress = honors.where((h) => !h.isCompleted).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (validated.isNotEmpty) ...[
              _SpecialtiesSubheader(
                label: 'Completadas · ${validated.length}',
                color: AppColors.secondary,
              ),
              const SizedBox(height: 6),
              _ChipWrap(
                items: validated
                    .map((h) => h.honorName ?? 'Especialidad')
                    .toList(),
                chipColor: AppColors.secondaryLight,
                textColor: AppColors.secondaryDark,
                borderColor: AppColors.secondary.withValues(alpha: 0.3),
              ),
            ],
            if (validated.isNotEmpty && inProgress.isNotEmpty)
              const SizedBox(height: 10),
            if (inProgress.isNotEmpty) ...[
              _SpecialtiesSubheader(
                label: 'En progreso · ${inProgress.length}',
                color: AppColors.accentDark,
              ),
              const SizedBox(height: 6),
              _ChipWrap(
                items: inProgress
                    .map((h) => h.honorName ?? 'Especialidad')
                    .toList(),
                chipColor: AppColors.accentLight,
                textColor: AppColors.accentDark,
                borderColor: AppColors.accent.withValues(alpha: 0.3),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SpecialtiesSubheader extends StatelessWidget {
  final String label;
  final Color color;

  const _SpecialtiesSubheader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ── Medical info section (role-restricted) ────────────────────────────────────

class _MedicalInfoSection extends ConsumerWidget {
  final String userId;

  const _MedicalInfoSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                'INFORMACIÓN MÉDICA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Confidencial',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        _MedicalCard(
          icon: HugeIcons.strokeRoundedFirstAidKit,
          title: 'Alergias',
          iconColor: AppColors.error,
          child: _AllergiesBody(userId: userId),
        ),
        const SizedBox(height: 10),
        _MedicalCard(
          icon: HugeIcons.strokeRoundedHealth,
          title: 'Enfermedades',
          iconColor: AppColors.accent,
          child: _DiseasesBody(userId: userId),
        ),
        const SizedBox(height: 10),
        _MedicalCard(
          icon: HugeIcons.strokeRoundedMedicine01,
          title: 'Medicamentos',
          iconColor: AppColors.secondary,
          child: _MedicinesBody(userId: userId),
        ),
        const SizedBox(height: 10),
        _MedicalCard(
          icon: HugeIcons.strokeRoundedContactBook,
          title: 'Contactos de Emergencia',
          iconColor: AppColors.primary,
          child: _EmergencyContactsBody(userId: userId),
        ),
      ],
    );
  }
}

class _MedicalCard extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final Color iconColor;
  final Widget child;

  const _MedicalCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: icon,
                      color: iconColor,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: c.borderLight),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Medical body widgets ──────────────────────────────────────────────────────

class _AllergiesBody extends ConsumerWidget {
  final String userId;

  const _AllergiesBody({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memberAllergiesProvider(userId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SacLoadingSmall(),
      ),
      error: (e, _) => _MedicalError(
        onRetry: () => ref.invalidate(memberAllergiesProvider(userId)),
      ),
      data: (allergies) => allergies.isEmpty
          ? _EmptyLabel('Sin alergias registradas')
          : _ChipWrap(
              items: allergies.map((a) => a.name).toList(),
              chipColor: AppColors.errorLight,
              textColor: AppColors.errorDark,
              borderColor: AppColors.error.withValues(alpha: 0.3),
            ),
    );
  }
}

class _DiseasesBody extends ConsumerWidget {
  final String userId;

  const _DiseasesBody({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memberDiseasesProvider(userId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SacLoadingSmall(),
      ),
      error: (e, _) => _MedicalError(
        onRetry: () => ref.invalidate(memberDiseasesProvider(userId)),
      ),
      data: (diseases) => diseases.isEmpty
          ? _EmptyLabel('Sin enfermedades registradas')
          : _ChipWrap(
              items: diseases.map((d) => d.name).toList(),
              chipColor: AppColors.accentLight,
              textColor: AppColors.accentDark,
              borderColor: AppColors.accent.withValues(alpha: 0.3),
            ),
    );
  }
}

class _MedicinesBody extends ConsumerWidget {
  final String userId;

  const _MedicinesBody({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memberMedicinesProvider(userId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SacLoadingSmall(),
      ),
      error: (e, _) => _MedicalError(
        onRetry: () => ref.invalidate(memberMedicinesProvider(userId)),
      ),
      data: (medicines) => medicines.isEmpty
          ? _EmptyLabel('Sin medicamentos registrados')
          : _ChipWrap(
              items: medicines.map((m) => m.name).toList(),
              chipColor: AppColors.secondaryLight,
              textColor: AppColors.secondaryDark,
              borderColor: AppColors.secondary.withValues(alpha: 0.3),
            ),
    );
  }
}

class _EmergencyContactsBody extends ConsumerWidget {
  final String userId;

  const _EmergencyContactsBody({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final async = ref.watch(memberEmergencyContactsProvider(userId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SacLoadingSmall(),
      ),
      error: (e, _) => _MedicalError(
        onRetry: () => ref.invalidate(memberEmergencyContactsProvider(userId)),
      ),
      data: (contacts) {
        if (contacts.isEmpty) {
          return _EmptyLabel('Sin contactos de emergencia registrados');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contacts.map((contact) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedUser,
                        color: AppColors.primaryDark,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        Text(
                          '${contact.relationshipTypeName ?? contact.relationshipTypeId} · ${contact.phone}',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Shared micro-widgets ──────────────────────────────────────────────────────

class _ChipWrap extends StatelessWidget {
  final List<String> items;
  final Color chipColor;
  final Color textColor;
  final Color borderColor;

  const _ChipWrap({
    required this.items,
    required this.chipColor,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((name) {
        return Chip(
          label: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: chipColor,
          side: BorderSide(color: borderColor),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }).toList(),
    );
  }
}

class _EmptyLabel extends StatelessWidget {
  final String text;

  const _EmptyLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: context.sac.textTertiary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _MedicalError extends StatelessWidget {
  final VoidCallback onRetry;

  const _MedicalError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          size: 16,
          color: AppColors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Error al cargar',
            style: TextStyle(fontSize: 13, color: AppColors.error),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _MemberProfileHeader extends StatelessWidget {
  final ClubMember member;

  const _MemberProfileHeader({required this.member});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryLight,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primarySurface,
            backgroundImage: member.avatar != null
                ? CachedNetworkImageProvider(member.avatar!)
                : null,
            child: member.avatar == null
                ? Text(
                    member.initials,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.fullName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  letterSpacing: -0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (member.clubRole != null)
                    SacBadge(
                      label: RoleUtils.translate(
                          member.clubRole, gender: member.gender),
                      variant: SacBadgeVariant.primary,
                    ),
                  if (member.currentClass != null)
                    SacBadge(
                      label: member.currentClass!,
                      variant: SacBadgeVariant.secondary,
                    ),
                  SacBadge(
                    label: member.isEnrolled ? 'Inscrito' : 'No inscrito',
                    variant: member.isEnrolled
                        ? SacBadgeVariant.secondary
                        : SacBadgeVariant.neutral,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar el perfil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
