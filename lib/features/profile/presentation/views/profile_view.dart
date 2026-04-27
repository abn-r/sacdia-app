import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
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
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../validation/presentation/widgets/eligibility_banner.dart';
import '../../domain/entities/user_detail.dart';
import '../providers/profile_providers.dart';
import '../../../achievements/presentation/widgets/achievement_profile_summary.dart';
import '../widgets/class_status_circles.dart';
import '../widgets/profile_classes_section.dart';
import '../widgets/profile_honors_section.dart';
import '../widgets/setting_tile.dart';
import '../../../qr/presentation/views/member_qr_view.dart';
import 'edit_profile_view.dart';
import 'medical_info_view.dart';
import 'settings_view.dart';

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
            toolbarTitle: 'profile.view.crop_photo_title'.tr(),
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'profile.view.crop_photo_title'.tr(),
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
                  content: Text('profile.view.photo_upload_error'.tr()),
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
                  content: Text('profile.view.photo_upload_success'.tr()),
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
            content: Text('profile.view.photo_upload_error'.tr()),
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
                  'profile.view.load_profile_error'.tr(),
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

            final activeRoleName =
                authUser?.authorization?.activeGrant?.roleName;

            return _ProfileScrollBody(
              profile: profile,
              authUser: authUser,
              activeRoleName: activeRoleName,
              isUploadingPhoto: _isUploadingPhoto,
              hPad: hPad,
              onChangePhoto: _isUploadingPhoto ? null : _changePhoto,
              onSettings: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsView()),
              ),
              onQr: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemberQrView()),
              ),
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
                    'profile.view.load_error'.tr(),
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
                    text: 'common.retry'.tr(),
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
  /// Raw club role name from the active grant (e.g. "director", "instructor").
  /// Null when the user has no active club assignment.
  final String? activeRoleName;
  final bool isUploadingPhoto;
  final double hPad;
  final VoidCallback? onChangePhoto;
  final Future<void> Function() onRefresh;
  final VoidCallback onRefreshClasses;
  final VoidCallback onRefreshHonors;
  final VoidCallback onSettings;
  final VoidCallback onQr;

  const _ProfileScrollBody({
    required this.profile,
    required this.authUser,
    required this.activeRoleName,
    required this.isUploadingPhoto,
    required this.hPad,
    required this.onRefresh,
    required this.onRefreshClasses,
    required this.onRefreshHonors,
    required this.onSettings,
    required this.onQr,
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
                        'profile.view.user_profile'.tr(),
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
                      icon: HugeIcons.strokeRoundedQrCode,
                      color: c.text,
                      size: 24,
                    ),
                    onPressed: onQr,
                    tooltip: 'profile.view.qr_tooltip'.tr(),
                  ),
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedSettings01,
                      color: c.text,
                      size: 24,
                    ),
                    onPressed: onSettings,
                    tooltip: 'profile.view.settings_tooltip'.tr(),
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
                clubRole: activeRoleName,
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

            // ── 2. Información médica (inline entry) ──────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border, width: 1),
                ),
                child: SettingTile(
                  icon: HugeIcons.strokeRoundedFirstAidKit,
                  title: 'profile.view.medical_info_title'.tr(),
                  subtitle: 'profile.view.medical_info_subtitle'.tr(),
                  iconColor: AppColors.error,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MedicalInfoView(),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: StaggeredColumn(
                initialDelay: const Duration(milliseconds: 100),
                staggerDelay: const Duration(milliseconds: 65),
                children: [
                  // ── 4. Elegibilidad para investidura ─────────────
                  // Only rendered for users with users:read_detail permission.
                  // Regular members lack this permission and would receive a
                  // 403 from GET /api/v1/validation/eligibility/{userId}.
                  if (authUser != null &&
                      hasAnyPermission(authUser, const {'users:read_detail'})) ...[
                    EligibilityBanner(userId: authUser!.id),
                    const SizedBox(height: 20),
                  ],

                  // ── 5. Clases Progresivas ─────────────────────────
                  _SectionLabel(label: 'profile.view.section_progressive_classes'.tr()),
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
                  _SectionLabel(label: 'profile.view.section_my_classes'.tr()),
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
                  _SectionLabel(label: 'profile.view.section_honors'.tr()),
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

            const SizedBox(height: 20),

            // ── 7. Logros ─────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: _SectionLabel(label: 'profile.view.section_achievements'.tr()),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: const AchievementProfileSummary(),
            ),

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
  /// Raw club role name from the active grant (e.g. "director", "instructor").
  /// Null when the user has no active club assignment — row is hidden in that case.
  final String? clubRole;
  final String? gender;
  final String? clubName;
  final String? clubType;
  final String? currentClass;
  final bool isUploadingPhoto;
  final VoidCallback? onEditPhoto;
  final VoidCallback? onEditProfile;

  const _ProfileHeaderCard({
    required this.name,
    required this.clubRole,
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
    final translated = RoleUtils.translate(clubRole, gender: gender);
    final roleLabel = translated.isNotEmpty ? translated : null;

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
                              text: 'profile.view.club_label'.tr(namedArgs: {'name': clubName!}),
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Tipo de club
                          if (clubType != null) ...[
                            _MetaRow(
                              icon: HugeIcons.strokeRoundedGridView,
                              text: 'profile.view.type_label'.tr(namedArgs: {'type': clubType!}),
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Cargo / Role
                          if (roleLabel != null) ...[
                            _MetaRow(
                              icon: HugeIcons.strokeRoundedLabel,
                              text: 'profile.view.role_label'.tr(namedArgs: {'role': roleLabel}),
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Clase
                          if (currentClass != null) ...[
                            _MetaRow(
                              icon: HugeIcons.strokeRoundedSchool,
                              text: 'profile.view.class_label'.tr(namedArgs: {'name': currentClass!}),
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
                                ClipOval(
                                  child: SizedBox(
                                    width: avatarRadius * 2,
                                    height: avatarRadius * 2,
                                    child: avatar != null
                                        ? CachedNetworkImage(
                                            imageUrl: avatar!,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 176,
                                            memCacheHeight: 176,
                                            placeholder: (_, __) =>
                                                _AvatarInitials(
                                              name: name,
                                              fontSize: fallbackFontSize,
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                _AvatarInitials(
                                              name: name,
                                              fontSize: fallbackFontSize,
                                            ),
                                          )
                                        : _AvatarInitials(
                                            name: name,
                                            fontSize: fallbackFontSize,
                                          ),
                                  ),
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
                    text: 'profile.view.update_profile'.tr(),
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

/// Placeholder de iniciales para cuando la imagen falla o no existe.
/// Mostrado tanto en estado de error como cuando la URL es nula.
class _AvatarInitials extends StatelessWidget {
  final String name;
  final double fontSize;

  const _AvatarInitials({required this.name, required this.fontSize});

  String _initials() {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        _initials(),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
