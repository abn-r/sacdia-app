import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/info_section.dart';

import '../../domain/entities/club_member.dart';

/// Vista de perfil de miembro (solo lectura).
///
/// Se usa tanto para miembros del club como para solicitantes de ingreso.
/// No permite editar ningún dato por seguridad.
class MemberProfileView extends StatelessWidget {
  final ClubMember? member;
  final String? title;
  final bool isLoading;
  final String? error;

  const MemberProfileView({
    super.key,
    this.member,
    this.title,
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);

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
        // Read-only lock indicator
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
        child: _buildBody(context, c, hPad),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SacColors c, double hPad) {
    if (isLoading) {
      return const Center(child: SacLoading());
    }

    if (error != null) {
      return _ErrorState(message: error!);
    }

    if (member == null) {
      return Center(
        child: Text(
          'No se pudo cargar el perfil',
          style: TextStyle(color: c.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Header ───────────────────────────────────────────────────
          _MemberProfileHeader(member: member!),

          const SizedBox(height: 24),

          // ── Información personal ──────────────────────────────────────
          InfoSection(
            title: 'Información Personal',
            items: [
              InfoItem(
                icon: HugeIcons.strokeRoundedUser,
                label: 'Nombre completo',
                value: member!.fullName,
              ),
              if (member!.email != null)
                InfoItem(
                  icon: HugeIcons.strokeRoundedMail01,
                  label: 'Correo electrónico',
                  value: member!.email,
                ),
              if (member!.phone != null)
                InfoItem(
                  icon: HugeIcons.strokeRoundedCall,
                  label: 'Teléfono',
                  value: member!.phone,
                ),
              if (member!.birthDate != null)
                InfoItem(
                  icon: HugeIcons.strokeRoundedBirthdayCake,
                  label: 'Fecha de nacimiento',
                  value: DateFormat('dd/MM/yyyy').format(member!.birthDate!),
                ),
              if (member!.gender != null)
                InfoItem(
                  icon: HugeIcons.strokeRoundedUser,
                  label: 'Género',
                  value: member!.gender,
                ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Información del club ──────────────────────────────────────
          InfoSection(
            title: 'Información del Club',
            items: [
              if (member!.clubRole != null)
                InfoItem(
                  icon: HugeIcons.strokeRoundedLabel,
                  label: 'Cargo en el club',
                  value: RoleUtils.translate(member!.clubRole),
                ),
              if (member!.currentClass != null)
                InfoItem(
                  icon: HugeIcons.strokeRoundedSchool,
                  label: 'Clase progresiva',
                  value: member!.currentClass,
                ),
              InfoItem(
                icon: HugeIcons.strokeRoundedTicketStar,
                label: 'Estado de inscripción',
                value: member!.isEnrolled ? 'Inscrito' : 'No inscrito',
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Header del perfil de miembro: avatar grande + nombre + badges
class _MemberProfileHeader extends StatelessWidget {
  final ClubMember member;

  const _MemberProfileHeader({required this.member});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
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

        // Name + badges
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
                      label: RoleUtils.translate(member.clubRole),
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
