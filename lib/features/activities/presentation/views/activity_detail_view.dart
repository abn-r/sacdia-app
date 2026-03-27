import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/activity.dart';
import '../providers/activities_providers.dart';
import '../widgets/activity_attendees_section.dart';
import '../widgets/activity_detail_skeleton.dart';
import '../widgets/activity_hero_section.dart';
import '../widgets/activity_metadata_grid.dart';
import 'edit_activity_view.dart';

/// Activity detail screen — Apple Maps / Airbnb-style layout.
///
/// Layout:
///   A) Edge-to-edge hero (map / image) behind the transparent AppBar
///   B) Title + type chip row, platform badge aligned right
///   C) 2×3 metadata grid with colored tinted backgrounds
///   D) Description (expandable)
///   E) Meet link card (virtual/hybrid only)
///   F) Participants section (read-only, from attendees field)
///   G) Creator card footer
///
/// The fixed bottom action bar has been removed — attendance is admin-only.
const double _kHeroHeight = 300.0;

class ActivityDetailView extends ConsumerStatefulWidget {
  final int activityId;

  const ActivityDetailView({
    super.key,
    required this.activityId,
  });

  @override
  ConsumerState<ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends ConsumerState<ActivityDetailView> {
  bool _descriptionExpanded = false;

  // ── type helpers ────────────────────────────────────────────────────────────

  Color _typeColor(int type) {
    switch (type) {
      case 1:
        return AppColors.sacBlue;
      case 2:
        return AppColors.accent;
      case 3:
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  String _typeLabel(int type, String? typeName) {
    final name = typeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    switch (type) {
      case 1:
        return 'Regular';
      case 2:
        return 'Especial';
      case 3:
        return 'Camporee';
      default:
        return 'Actividad';
    }
  }

  // ── navigation ──────────────────────────────────────────────────────────────

  Future<void> _navigateToEdit(Activity activity) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditActivityView(activity: activity)),
    );
    if (result == true && mounted) {
      ref.invalidate(activityDetailProvider(widget.activityId));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: const Text(
          '¿Estás seguro que querés eliminar esta actividad? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final success = await ref
        .read(deleteActivityNotifierProvider.notifier)
        .delete(widget.activityId);

    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Actividad eliminada correctamente'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      navigator.pop();
    } else {
      final deleteState = ref.read(deleteActivityNotifierProvider);
      final errorMsg = deleteState.hasError
          ? deleteState.error?.toString() ?? 'Error al eliminar'
          : 'Error al eliminar';
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── meet link ───────────────────────────────────────────────────────────────

  Future<void> _openMeetLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── relative date ───────────────────────────────────────────────────────────

  String _relativeDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date.toLocal()).inDays;
    if (diff == 0) return 'hoy';
    if (diff == 1) return 'ayer';
    if (diff < 7) return 'hace $diff días';
    if (diff < 30) return 'hace ${(diff / 7).floor()} semanas';
    return DateFormat('d MMM yyyy', 'es').format(date.toLocal());
  }

  // ── build sections ──────────────────────────────────────────────────────────

  // ── platform badge helpers (mirrors ActivityHeroSection) ───────────────────

  String _platformLabel(int platform) {
    switch (platform) {
      case 1:
        return 'Virtual';
      case 2:
        return 'Híbrido';
      default:
        return 'Presencial';
    }
  }

  Color _platformColor(int platform) {
    switch (platform) {
      case 1:
        return AppColors.sacBlue;
      case 2:
        return AppColors.accent;
      default:
        return AppColors.secondary;
    }
  }

  Widget _buildTitleSection(BuildContext context, Activity activity) {
    final typeColor = _typeColor(activity.activityType);
    final typeText = _typeLabel(activity.activityType, activity.activityTypeName);
    final platColor = _platformColor(activity.platform);
    final platText = _platformLabel(activity.platform);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.name,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 8),
        // Type badge (left) + Platform badge (right) on the same row
        Row(
          children: [
            // Activity type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                typeText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: typeColor,
                ),
              ),
            ),
            const Spacer(),
            // Platform badge — moved here from hero overlay
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: platColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: platColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                platText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: platColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context, String description) {
    // Warm gray — slightly warmer than pure slate-500
    const warmGray = Color(0xFF6B7280);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Descripción'),
        const SizedBox(height: 10),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _descriptionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: warmGray,
                  height: 1.6,
                ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          secondChild: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: warmGray,
                  height: 1.6,
                ),
          ),
        ),
        if (description.length > 200)
          GestureDetector(
            onTap: () =>
                setState(() => _descriptionExpanded = !_descriptionExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _descriptionExpanded ? 'Ver menos' : 'Ver más',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMeetLinkSection(BuildContext context, String url) {
    return SacCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.sacBlue.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sacBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedComputerVideoCall,
                size: 20,
                color: AppColors.sacBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reunión virtual',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unirse a la llamada',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.sac.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: () => _openMeetLink(url),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sacBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Unirse'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorFooter(BuildContext context, Activity activity) {
    final sac = context.sac;
    final createdDate = activity.createdAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sac.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sac.border),
      ),
      child: Row(
        children: [
          _CreatorAvatar(
            imageUrl: activity.creatorImage,
            name: activity.creatorName,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Organizador',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: sac.textTertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.creatorName ?? 'Sistema',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (createdDate != null)
                  Text(
                    _relativeDate(createdDate),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: sac.textTertiary,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar action button (circular, white, with dark scrim) ─────────────────

  Widget _buildHeroAction({
    required BuildContext context,
    required Widget child,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }

  // ── main build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityDetailProvider(widget.activityId));
    final deleteState = ref.watch(deleteActivityNotifierProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.sac.background,
        body: activityAsync.when(
          loading: () => const ActivityDetailSkeleton(),

          error: (error, _) => Column(
            children: [
              AppBar(
                backgroundColor: context.sac.background,
                foregroundColor: context.sac.text,
                elevation: 0,
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
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
                          'No se pudo cargar la actividad',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString().replaceAll('Exception: ', ''),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: context.sac.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 28),
                        SacButton.primary(
                          text: 'Reintentar',
                          icon: HugeIcons.strokeRoundedRefresh,
                          onPressed: () => ref.invalidate(
                              activityDetailProvider(widget.activityId)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          data: (activity) {
            return CustomScrollView(
              slivers: [
                // ── Edge-to-edge hero SliverAppBar ────────────────────────
                SliverAppBar(
                  pinned: true,
                  expandedHeight: _kHeroHeight,
                  backgroundColor: context.sac.background,
                  // Transparent when expanded, solid when collapsed
                  surfaceTintColor: Colors.transparent,
                  systemOverlayStyle: SystemUiOverlayStyle.light,
                  // Use default leading for collapsed state
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // When collapsed: show title
                  title: Text(
                    activity.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Collapsed AppBar uses the default surface color (already set above)
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      // Detect if the app bar is collapsed
                      final topPadding = MediaQuery.of(context).padding.top;
                      final collapsedHeight = kToolbarHeight + topPadding;
                      final isCollapsed =
                          constraints.maxHeight <= collapsedHeight + 1;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Hero content — full bleed, no border radius
                          if (!isCollapsed)
                            ActivityHeroSection(activity: activity),
                          // Collapsed: just a solid background (handled by backgroundColor)
                          // Status-bar-aware action buttons (always visible)
                          Positioned(
                            top: topPadding + 8,
                            left: 12,
                            child: _buildHeroAction(
                              context: context,
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          Positioned(
                            top: topPadding + 8,
                            right: 12,
                            child: Row(
                              children: [
                                _buildHeroAction(
                                  context: context,
                                  onPressed: deleteState.isLoading
                                      ? null
                                      : () => _navigateToEdit(activity),
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedEdit02,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildHeroAction(
                                  context: context,
                                  onPressed: deleteState.isLoading
                                      ? null
                                      : _confirmDelete,
                                  child: deleteState.isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // ── Scrollable content sheet ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // B) Title + type chip + platform badge row
                        _buildTitleSection(context, activity),

                        const SizedBox(height: 8),

                        // C) Metadata grid
                        ActivityMetadataGrid(activity: activity),

                        // D) Description — reduced gap from grid
                        if (activity.description != null &&
                            activity.description!.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildDescriptionSection(
                              context, activity.description!),
                        ],

                        // E) Meet link
                        if (activity.hasVirtualLink) ...[
                          const SizedBox(height: 20),
                          _buildMeetLinkSection(context, activity.linkMeet!),
                        ],

                        // F) Participants (read-only from attendees field)
                        const SizedBox(height: 20),
                        ActivityAttendeesSection(
                          attendees: activity.attendees ?? [],
                        ),

                        // G) Creator footer card
                        const SizedBox(height: 20),
                        _buildCreatorFooter(context, activity),

                        // Bottom padding — no fixed bar, just natural scroll space
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── _CreatorAvatar ─────────────────────────────────────────────────────────────

class _CreatorAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;

  const _CreatorAvatar({this.imageUrl, this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final initial = name != null && name!.isNotEmpty
        ? name![0].toUpperCase()
        : '?';

    if (hasImage) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildInitials(context, initial),
        ),
      );
    }

    return _buildInitials(context, initial);
  }

  Widget _buildInitials(BuildContext context, String initial) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}
