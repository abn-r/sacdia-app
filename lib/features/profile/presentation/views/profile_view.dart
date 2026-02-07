import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/info_section.dart';
import '../widgets/profile_header.dart';
import '../widgets/setting_tile.dart';
import 'edit_profile_view.dart';
import 'settings_view.dart';

/// Vista principal del perfil del usuario
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);

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
                    color: AppColors.sacBlack,
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.sacGreen,
              onRefresh: () async {
                await ref.read(profileNotifierProvider.notifier).refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Encabezado con foto y nombre
                    ProfileHeader(
                      name: profile.fullName,
                      email: profile.email,
                      avatar: profile.avatar,
                      onEditPhoto: () {
                        // TODO: Implementar cambio de foto
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cambio de foto próximamente'),
                          ),
                        );
                      },
                    ),
                    // Contenido
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.paddingM),
                      child: Column(
                        children: [
                          // Botón de editar perfil
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const EditProfileView(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar Perfil'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.sacGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppConstants.paddingM,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppConstants.paddingM),
                          // Información personal
                          InfoSection(
                            title: 'Información Personal',
                            items: [
                              InfoItem(
                                icon: Icons.person,
                                label: 'Nombre completo',
                                value: profile.fullName,
                              ),
                              InfoItem(
                                icon: Icons.email,
                                label: 'Correo electrónico',
                                value: profile.email,
                              ),
                              if (profile.phone != null)
                                InfoItem(
                                  icon: Icons.phone,
                                  label: 'Teléfono',
                                  value: profile.phone,
                                ),
                              if (profile.birthDate != null)
                                InfoItem(
                                  icon: Icons.cake,
                                  label: 'Fecha de nacimiento',
                                  value: DateFormat('dd/MM/yyyy')
                                      .format(profile.birthDate!),
                                ),
                              if (profile.gender != null)
                                InfoItem(
                                  icon: Icons.person_outline,
                                  label: 'Género',
                                  value: profile.gender,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.paddingM),
                          // Información del club
                          if (profile.clubName != null) ...[
                            InfoSection(
                              title: 'Mi Club',
                              items: [
                                InfoItem(
                                  icon: Icons.groups,
                                  label: 'Club',
                                  value: profile.clubName,
                                ),
                                if (profile.clubType != null)
                                  InfoItem(
                                    icon: Icons.category,
                                    label: 'Tipo',
                                    value: profile.clubType,
                                  ),
                                if (profile.roles.isNotEmpty)
                                  InfoItem(
                                    icon: Icons.badge,
                                    label: 'Rol',
                                    value: profile.roles.join(', '),
                                  ),
                                if (profile.currentClass != null)
                                  InfoItem(
                                    icon: Icons.school,
                                    label: 'Clase actual',
                                    value: profile.currentClass,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.paddingM),
                          ],
                          // Configuración
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                SettingTile(
                                  icon: Icons.settings,
                                  title: 'Configuración',
                                  subtitle: 'Tema, notificaciones y más',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SettingsView(),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                SettingTile(
                                  icon: Icons.logout,
                                  title: 'Cerrar sesión',
                                  iconColor: AppColors.error,
                                  onTap: () async {
                                    final shouldLogout = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Cerrar sesión'),
                                        content: const Text(
                                          '¿Estás seguro que deseas cerrar sesión?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                            ),
                                            child: const Text('Cerrar sesión'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (shouldLogout == true) {
                                      await ref
                                          .read(authNotifierProvider.notifier)
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
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.sacGreen,
            ),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppConstants.paddingM),
                  const Text(
                    'Error al cargar el perfil',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.sacBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.paddingS),
                  Text(
                    error.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.paddingL),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(profileNotifierProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sacGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingL,
                        vertical: AppConstants.paddingM,
                      ),
                    ),
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
