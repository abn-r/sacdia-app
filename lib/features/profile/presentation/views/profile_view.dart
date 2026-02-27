import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/class_status_circles.dart';
import '../widgets/info_section.dart';
import '../widgets/profile_honors_section.dart';
import '../widgets/setting_tile.dart';
import 'edit_profile_view.dart';
import 'settings_view.dart';

// ─── Settings sheet helpers ──────────────────────────────────────────────────

void _showSettingsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SettingsSheet(ref: ref),
  );
}

class _SettingsSheet extends StatelessWidget {
  final WidgetRef ref;

  const _SettingsSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ───────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Main actions group ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Column(
                children: [
                  SettingTile(
                    icon: HugeIcons.strokeRoundedEdit02,
                    title: 'Editar perfil',
                    subtitle: 'Actualiza tu información personal',
                    iconColor: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileView(),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 60,
                    color: c.borderLight,
                  ),
                  SettingTile(
                    icon: HugeIcons.strokeRoundedSettings01,
                    title: 'Configuración',
                    subtitle: 'Tema, notificaciones y más',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsView(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Destructive action group ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border, width: 1),
              ),
              child: SettingTile(
                icon: HugeIcons.strokeRoundedLogout01,
                title: 'Cerrar sesión',
                iconColor: AppColors.error,
                onTap: () async {
                  Navigator.pop(context);
                  final shouldLogout = await SacDialog.show(
                    context,
                    title: 'Cerrar sesión',
                    content: '¿Estás seguro que deseas cerrar sesión?',
                    confirmLabel: 'Cerrar sesión',
                    confirmIsDestructive: true,
                  );

                  if (shouldLogout == true) {
                    await ref.read(authNotifierProvider.notifier).signOut();
                  }
                },
              ),
            ),
          ),

          // ── Safe area bottom padding ──────────────────────────────
          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);
    final hPad = Responsive.horizontalPadding(context);

    final c = context.sac;

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      body: SafeArea(
        child: profileState.when(
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Text(
                  'No se pudo cargar el perfil',
                  style: TextStyle(
                    fontSize: 16,
                    color: c.textSecondary,
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await ref.read(profileNotifierProvider.notifier).refresh();
                ref.invalidate(userHonorsProvider);
                ref.invalidate(userHonorStatsProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Gear icon row ──────────────────────────────────
                    Padding(
                      padding: EdgeInsets.only(right: hPad, top: 8, bottom: 0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedSettings01,
                            color: c.textSecondary,
                            size: 22,
                          ),
                          onPressed: () => _showSettingsSheet(context, ref),
                          tooltip: 'Ajustes',
                        ),
                      ),
                    ),

                    // ── 1. Header Card ────────────────────────────────────
                    StaggeredListItem(
                      index: 0,
                      initialDelay: const Duration(milliseconds: 40),
                      child: _ProfileHeaderCard(
                        name: profile.fullName,
                        avatar: profile.avatar,
                        roles: profile.roles,
                        clubName: profile.clubName,
                        currentClass: profile.currentClass,
                        onEditPhoto: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Cambio de foto próximamente'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        onEditProfile: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileView(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: StaggeredColumn(
                        initialDelay: const Duration(milliseconds: 100),
                        staggerDelay: const Duration(milliseconds: 65),
                        children: [
                          // ── 2. Sección: Información Personal ─────────────
                          InfoSection(
                            title: 'Información Personal',
                            items: [
                              InfoItem(
                                icon: HugeIcons.strokeRoundedUser,
                                label: 'Nombre completo',
                                value: profile.fullName,
                              ),
                              InfoItem(
                                icon: HugeIcons.strokeRoundedMail01,
                                label: 'Correo electrónico',
                                value: profile.email,
                              ),
                              if (profile.phone != null)
                                InfoItem(
                                  icon: HugeIcons.strokeRoundedCall,
                                  label: 'Teléfono',
                                  value: profile.phone,
                                ),
                              if (profile.birthDate != null)
                                InfoItem(
                                  icon: HugeIcons.strokeRoundedBirthdayCake,
                                  label: 'Fecha de nacimiento',
                                  value: DateFormat('dd/MM/yyyy')
                                      .format(profile.birthDate!),
                                ),
                              if (profile.gender != null)
                                InfoItem(
                                  icon: HugeIcons.strokeRoundedUser,
                                  label: 'Género',
                                  value: profile.gender,
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── 3. Sección: Mi Club ───────────────────────────
                          if (profile.clubName != null) ...[
                            InfoSection(
                              title: 'Mi Club',
                              items: [
                                InfoItem(
                                  icon: HugeIcons.strokeRoundedUserGroup,
                                  label: 'Club',
                                  value: profile.clubName,
                                ),
                                if (profile.clubType != null)
                                  InfoItem(
                                    icon: HugeIcons.strokeRoundedGridView,
                                    label: 'Tipo',
                                    value: profile.clubType,
                                  ),
                                if (profile.roles.isNotEmpty)
                                  InfoItem(
                                    icon: HugeIcons.strokeRoundedLabel,
                                    label: 'Rol',
                                    value:
                                        RoleUtils.translateList(profile.roles),
                                  ),
                                if (profile.currentClass != null)
                                  InfoItem(
                                    icon: HugeIcons.strokeRoundedSchool,
                                    label: 'Clase actual',
                                    value: profile.currentClass,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ── 4. Clases Progresivas ─────────────────────────
                          _SectionLabel(label: 'Clases Progresivas'),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: c.border,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 16,
                            ),
                            child: const ClassStatusCircles(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                    // ── 5. Especialidades ─────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _SectionLabel(label: 'Especialidades'),
                          GestureDetector(
                            onTap: () {
                              ref.invalidate(userHonorsProvider);
                              ref.invalidate(userHonorStatsProvider);
                              ref.invalidate(honorCategoriesProvider);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: c.border,
                                ),
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedRefresh,
                                  color: c.textTertiary,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    const ProfileHonorsSection(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: SacLoading()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 56,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar el perfil',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SacButton.primary(
                    text: 'Reintentar',
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: () {
                      ref.read(profileNotifierProvider.notifier).refresh();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Private Widgets ────────────────────────────────────────────────────────

/// Header card with a two-column layout:
/// LEFT  — name (large, bold) + meta rows (club, cargo, clase)
/// RIGHT — circular avatar with camera edit overlay
/// BELOW — full-width "Actualizar perfil" button
///
/// White card with a solid 6px primary top strip. No gradients.
class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String? avatar;
  final List<String> roles;
  final String? clubName;
  final String? currentClass;
  final VoidCallback? onEditPhoto;
  final VoidCallback? onEditProfile;

  const _ProfileHeaderCard({
    required this.name,
    required this.roles,
    this.avatar,
    this.clubName,
    this.currentClass,
    this.onEditPhoto,
    this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    // Fixed avatar radius for the side-by-side layout — compact but readable.
    const double avatarRadius = 52.0;
    const double fallbackFontSize = 32.0;
    final roleLabel =
        roles.isNotEmpty ? RoleUtils.translateList(roles) : null;

    final c = context.sac;

    return Container(
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Solid 6px accent strip ─────────────────────────────
          Container(
            height: 6,
            color: AppColors.primary,
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top row: info (left) + avatar (right) ─────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Left: name + meta rows ─────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                  letterSpacing: -0.3,
                                  fontSize: 20,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 10),

                          // Club
                          if (clubName != null) ...[
                            _MetaRow(
                              icon: HugeIcons.strokeRoundedUserGroup,
                              text: clubName!,
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Cargo / Role
                          if (roleLabel != null) ...[
                            _MetaRow(
                              icon: HugeIcons.strokeRoundedLabel,
                              text: roleLabel,
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Clase
                          if (currentClass != null)
                            _MetaRow(
                              icon: HugeIcons.strokeRoundedSchool,
                              text: currentClass!,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // ── Right: circular avatar with camera button ──
                    Stack(
                      clipBehavior: Clip.none,
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
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: AppColors.primarySurface,
                            backgroundImage: avatar != null
                                ? NetworkImage(avatar!)
                                : null,
                            child: avatar == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: fallbackFontSize,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (onEditPhoto != null)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: onEditPhoto,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: c.background,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.border,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedCamera01,
                                    color: c.textSecondary,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Full-width CTA button ──────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: SacButton.primary(
                    text: 'Actualizar perfil',
                    icon: HugeIcons.strokeRoundedEdit02,
                    onPressed: onEditProfile,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single meta row used inside the header left column.
/// Shows a small HugeIcon on the left and a text label on the right.
class _MetaRow extends StatelessWidget {
  final dynamic icon;
  final String text;

  const _MetaRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HugeIcon(
          icon: icon,
          color: context.sac.textTertiary,
          size: 15,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.sac.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Section label — uppercase small text in tertiary grey.
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.sac.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}
