import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/logout_cleanup.dart';
import '../../../validation/presentation/widgets/eligibility_banner.dart';
import '../../domain/entities/user_detail.dart';
import '../providers/profile_providers.dart';
import '../widgets/class_status_circles.dart';
import '../widgets/profile_classes_section.dart';
import '../widgets/profile_honors_section.dart';
import '../widgets/setting_tile.dart';
import 'edit_profile_view.dart';
import 'medical_info_view.dart';
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
                    icon: HugeIcons.strokeRoundedFirstAidKit,
                    title: 'Información Médica',
                    subtitle: 'Alergias, enfermedades, medicamentos y contactos de emergencia',
                    iconColor: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MedicalInfoView(),
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
                    final success =
                        await ref.read(authNotifierProvider.notifier).signOut();
                    if (success) clearUserStateOnLogout(ref);
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

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  static const _tag = 'ProfileView';
  bool _isUploadingPhoto = false;

  Future<void> _changePhoto() async {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) return;

    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: photo.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar foto',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Recortar foto',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      try {
        final result = await ref
            .read(postRegistrationRepositoryProvider)
            .uploadProfilePicture(
              userId: user.id,
              filePath: croppedFile.path,
            );

        result.fold(
          (failure) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('No se pudo subir la foto. Intentá de nuevo.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          },
          (_) {
            if (mounted) {
              ref.invalidate(profileNotifierProvider);
              ref.invalidate(authNotifierProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Foto actualizada correctamente'),
                  backgroundColor: AppColors.secondary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          },
        );
      } finally {
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
        }
      }
    } catch (e) {
      AppLogger.e('Error al cambiar foto de perfil', tag: _tag, error: e);
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo subir la foto. Intentá de nuevo.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final hPad = Responsive.horizontalPadding(context);

    final c = context.sac;

    // Use cached data if available so the header shows immediately on re-visits.
    final cachedProfile = profileState.valueOrNull;
    final isFirstLoad = cachedProfile == null && profileState.isLoading;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: profileState.when(
          skipLoadingOnReload: true,
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

            final authUser = ref.watch(
              authNotifierProvider.select((v) => v.valueOrNull),
            );

            return _ProfileScrollBody(
              profile: profile,
              authUser: authUser,
              isUploadingPhoto: _isUploadingPhoto,
              hPad: hPad,
              onChangePhoto: _isUploadingPhoto ? null : _changePhoto,
              onSettings: () => _showSettingsSheet(context, ref),
              onRefresh: () async {
                await ref.read(profileNotifierProvider.notifier).refresh();
                ref.invalidate(userClassesProvider);
                ref.invalidate(userHonorsProvider);
                // userHonorStatsLocalProvider recomputes automatically when
                // userHonorsProvider is invalidated.
              },
              onRefreshClasses: () => ref.invalidate(userClassesProvider),
              onRefreshHonors: () {
                ref.invalidate(userHonorsProvider);
                // userHonorStatsLocalProvider recomputes automatically.
              },
            );
          },
          loading: () {
            // On first load (no cached data) show a header skeleton so
            // the page layout is stable from the first frame.
            if (isFirstLoad) {
              return _ProfileFirstLoadSkeleton(hPad: hPad);
            }
            // Should not reach here because skipLoadingOnReload: true keeps
            // the previous data visible during background refreshes.
            return const SizedBox.shrink();
          },
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

/// Scrollable body shared between the data and (cached) loading states.
/// Extracted to avoid code duplication and keep [_ProfileViewState.build]
/// focused on state routing.
class _ProfileScrollBody extends StatelessWidget {
  final UserDetail profile;
  final UserEntity? authUser;
  final bool isUploadingPhoto;
  final double hPad;
  final VoidCallback? onChangePhoto;
  final Future<void> Function() onRefresh;
  final VoidCallback onRefreshClasses;
  final VoidCallback onRefreshHonors;
  final VoidCallback onSettings;

  const _ProfileScrollBody({
    required this.profile,
    required this.authUser,
    required this.isUploadingPhoto,
    required this.hPad,
    required this.onRefresh,
    required this.onRefreshClasses,
    required this.onRefreshHonors,
    required this.onSettings,
    this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── App bar row (Instagram style) ──────────────────
            Padding(
              padding: EdgeInsets.only(
                left: hPad,
                right: hPad / 2,
                top: 8,
                bottom: 4,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedLockKey,
                        color: c.text,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Perfil de usuario',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedMenu01,
                      color: c.text,
                      size: 24,
                    ),
                    onPressed: onSettings,
                    tooltip: 'Ajustes',
                  ),
                ],
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
                gender: profile.gender,
                clubName: profile.clubName,
                clubType: profile.clubType,
                currentClass: profile.currentClass,
                isUploadingPhoto: isUploadingPhoto,
                onEditPhoto: onChangePhoto,
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

            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: StaggeredColumn(
                initialDelay: const Duration(milliseconds: 100),
                staggerDelay: const Duration(milliseconds: 65),
                children: [
                  // ── 4. Elegibilidad para investidura ─────────────
                  if (authUser != null) ...[
                    EligibilityBanner(userId: authUser!.id),
                    const SizedBox(height: 20),
                  ],

                  // ── 5. Clases Progresivas ─────────────────────────
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
                    child: ClassStatusCircles(clubType: profile.clubType),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // ── 5. Clases del Usuario ────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SectionLabel(label: 'Mis Clases'),
                  GestureDetector(
                    onTap: onRefreshClasses,
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

            const ProfileClassesSection(),

            const SizedBox(height: 20),

            // ── 6. Especialidades ─────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SectionLabel(label: 'Especialidades'),
                  Row(
                    children: [
                      // Add honor button
                      GestureDetector(
                        onTap: () {
                          context.push(RouteNames.homeHonors);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.sacBlue.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.sacBlue.withAlpha(40),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add_rounded,
                              color: AppColors.sacBlue,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Refresh button
                      GestureDetector(
                        onTap: onRefreshHonors,
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
  }
}

/// Skeleton shown only on the very first load (no cached profile data).
/// Mirrors the layout of the real screen so the UI never jumps between states.
class _ProfileFirstLoadSkeleton extends StatelessWidget {
  final double hPad;

  const _ProfileFirstLoadSkeleton({required this.hPad});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final skeletonColor = c.surfaceVariant;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App bar placeholder
            const SizedBox(height: 52),

            // Header card skeleton
            Container(
              height: 160,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(14),
              ),
            ),

            // Eligibility banner skeleton
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(14),
              ),
            ),

            // Section label + class status circles skeleton
            Container(
              height: 12,
              width: 100,
              margin: const EdgeInsets.only(bottom: 8),
              color: skeletonColor,
            ),
            Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(14),
              ),
            ),

            // Classes section header skeleton
            Container(
              height: 20,
              width: 80,
              margin: const EdgeInsets.only(bottom: 8),
              color: skeletonColor,
            ),
            Container(
              height: 52,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 5,
                      right: i == 2 ? 0 : 5,
                    ),
                    child: Container(
                      height: 90,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Honors section header skeleton
            Container(
              height: 20,
              width: 100,
              margin: const EdgeInsets.only(bottom: 8),
              color: skeletonColor,
            ),
            Container(
              height: 52,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 5,
                      right: i == 2 ? 0 : 5,
                    ),
                    child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

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
  final String? gender;
  final String? clubName;
  final String? clubType;
  final String? currentClass;
  final bool isUploadingPhoto;
  final VoidCallback? onEditPhoto;
  final VoidCallback? onEditProfile;

  const _ProfileHeaderCard({
    required this.name,
    required this.roles,
    this.gender,
    this.avatar,
    this.clubName,
    this.clubType,
    this.currentClass,
    this.isUploadingPhoto = false,
    this.onEditPhoto,
    this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    // Fixed avatar radius for the side-by-side layout — compact but readable.
    const double avatarRadius = 50.0;
    const double fallbackFontSize = 32.0;
    final roleLabel =
        roles.isNotEmpty ? RoleUtils.translateList(roles, gender: gender) : null;

    final c = context.sac;

    return Container(
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                              text: 'Club: $clubName',
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Tipo de club
                          if (clubType != null) ...[
                            _MetaRow(
                              icon: HugeIcons.strokeRoundedGridView,
                              text: 'Tipo: $clubType',
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Cargo / Role
                          if (roleLabel != null) ...[
                            _MetaRow(
                              icon: HugeIcons.strokeRoundedLabel,
                              text: 'Rol: $roleLabel',
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Clase
                          if (currentClass != null) ...[
                            _MetaRow(
                              icon: HugeIcons.strokeRoundedSchool,
                              text: 'Clase: $currentClass',
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // ── Right: circular avatar with camera button ──
                    GestureDetector(
                      onTap: onEditPhoto,
                      child: Stack(
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
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: avatarRadius,
                                  backgroundColor: AppColors.primarySurface,
                                  backgroundImage: avatar != null
                                      ? CachedNetworkImageProvider(avatar!)
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
                                if (isUploadingPhoto)
                                  Container(
                                    width: avatarRadius * 2,
                                    height: avatarRadius * 2,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0x80000000),
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isUploadingPhoto)
                            Positioned(
                              bottom: 2,
                              right: 2,
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
                                      color: context.sac.shadow,
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
                        ],
                      ),
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
  final HugeIconData icon;
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
