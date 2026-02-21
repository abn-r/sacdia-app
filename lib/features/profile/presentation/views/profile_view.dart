import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/info_section.dart';
import '../widgets/profile_header.dart';
import '../widgets/setting_tile.dart';
import 'edit_profile_view.dart';
import 'settings_view.dart';

/// Vista principal del perfil del usuario
///
/// Secciones aparecen con staggered slide-up entrance.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: profileState.when(
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text(
                  'No se pudo cargar el perfil',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.lightText,
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await ref.read(profileNotifierProvider.notifier).refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Profile header fades in first
                    StaggeredListItem(
                      index: 0,
                      initialDelay: const Duration(milliseconds: 60),
                      child: ProfileHeader(
                        name: profile.fullName,
                        email: profile.email,
                        avatar: profile.avatar,
                        onEditPhoto: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Cambio de foto próximamente'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Content sections with staggered entrance
                    Padding(
                      padding: EdgeInsets.all(hPad),
                      child: StaggeredColumn(
                        initialDelay: const Duration(milliseconds: 140),
                        staggerDelay: const Duration(milliseconds: 80),
                        children: [
                          // Edit button
                          SacButton.primary(
                            text: 'Editar perfil',
                            icon: HugeIcons.strokeRoundedEdit02,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EditProfileView(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Personal info section
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
                          const SizedBox(height: 16),

                          // Club info section
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
                                    value: profile.roles.join(', '),
                                  ),
                                if (profile.currentClass != null)
                                  InfoItem(
                                    icon: HugeIcons.strokeRoundedSchool,
                                    label: 'Clase actual',
                                    value: profile.currentClass,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Settings card
                          SacCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                SettingTile(
                                  icon: HugeIcons.strokeRoundedSettings01,
                                  title: 'Configuración',
                                  subtitle: 'Tema, notificaciones y más',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SettingsView(),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                SettingTile(
                                  icon: HugeIcons.strokeRoundedLogout01,
                                  title: 'Cerrar sesión',
                                  iconColor: AppColors.error,
                                  onTap: () async {
                                    final shouldLogout =
                                        await SacDialog.show(
                                      context,
                                      title: 'Cerrar sesión',
                                      content:
                                          '¿Estás seguro que deseas cerrar sesión?',
                                      confirmLabel: 'Cerrar sesión',
                                      confirmIsDestructive: true,
                                    );

                                    if (shouldLogout == true) {
                                      await ref
                                          .read(authNotifierProvider
                                              .notifier)
                                          .signOut();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 56,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar el perfil',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightText,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SacButton.primary(
                    text: 'Reintentar',
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: () {
                      ref
                          .read(profileNotifierProvider.notifier)
                          .refresh();
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
