import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/evidence_folder_loading_skeleton.dart';
import '../widgets/evidence_folder_overview.dart';
import '../../domain/entities/evidence_folder.dart';
import '../../domain/entities/evidence_section.dart';
import '../providers/evidence_folder_providers.dart';
import '../widgets/folder_closed_banner.dart';
import '../widgets/section_card.dart';
import 'evidence_section_detail_view.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

/// Vista principal de la Carpeta Anual de Evidencias.
///
/// Muestra el encabezado de la carpeta (estado, progreso, puntos),
/// el banner de carpeta cerrada cuando aplica, y la lista de secciones.
///
/// [clubSectionId] identifica el contexto de club activo.
class EvidenceFolderView extends ConsumerWidget {
  final String clubSectionId;

  const EvidenceFolderView({
    super.key,
    required this.clubSectionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderAsync = ref.watch(evidenceFolderProvider(clubSectionId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: folderAsync.when(
          loading: () => const EvidenceFolderLoadingSkeleton(),
          // Path happy: backend nuevo (200 + data: null) → folder == null.
          // Path legacy: backend viejo (404 → NotFoundException) → error branch.
          // Ambos convergen en _NoFolderBody.
          data: (folder) => folder == null
              ? _NoFolderBody(
                  clubSectionId: clubSectionId,
                  onBack: () => Navigator.of(context).maybePop(),
                )
              : _FolderBody(
                  folder: folder,
                  clubSectionId: clubSectionId,
                ),
          error: (error, _) {
            // Fallback defensivo: backend viejo que todavía devuelve 404.
            if (error is NotFoundException) {
              return _NoFolderBody(
                clubSectionId: clubSectionId,
                onBack: () => Navigator.of(context).maybePop(),
              );
            }
            return _ErrorBody(
              message: error.toString().replaceFirst('Exception: ', ''),
              onRetry: () =>
                  ref.invalidate(evidenceFolderProvider(clubSectionId)),
              onBack: () => Navigator.of(context).maybePop(),
            );
          },
        ),
      ),
    );
  }
}

// ── Body cuando hay datos ──────────────────────────────────────────────────────

class _FolderBody extends ConsumerStatefulWidget {
  final EvidenceFolder folder;
  final String clubSectionId;

  const _FolderBody({
    required this.folder,
    required this.clubSectionId,
  });

  @override
  ConsumerState<_FolderBody> createState() => _FolderBodyState();
}

class _FolderBodyState extends ConsumerState<_FolderBody> {
  /// Tracks which sectionId is currently being submitted (null = none).
  String? _submittingSectionId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  List<EvidenceSection> get _filteredSections {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return widget.folder.sections;

    return widget.folder.sections.where((section) {
      final nameMatches = section.name.toLowerCase().contains(normalizedQuery);
      final descriptionMatches =
          section.description?.toLowerCase().contains(normalizedQuery) ?? false;
      return nameMatches || descriptionMatches;
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String query) {
    if (query == _query) return;
    setState(() => _query = query);
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
    _searchFocusNode.requestFocus();
  }

  Future<void> _handleSectionSubmit(EvidenceSection section) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'evidence_folder.submit_section_dialog.title'.tr(),
      content: 'evidence_folder.submit_section_dialog.message'.tr(namedArgs: {
        'sectionName': section.name,
      }),
      icon: HugeIcons.strokeRoundedMailSend01,
      cancelLabel: 'common.cancel'.tr(),
      confirmLabel: 'evidence_folder.send'.tr(),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submittingSectionId = section.id);

    final success = await ref
        .read(evidenceSectionNotifierProvider(widget.clubSectionId).notifier)
        .submitSection(section.id);

    if (!mounted) return;

    setState(() => _submittingSectionId = null);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: Colors.white,
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'evidence_folder.submit_success'.tr(namedArgs: {
                    'sectionName': section.name,
                  }),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      final errorMsg = ref
          .read(evidenceSectionNotifierProvider(widget.clubSectionId))
          .errorMessage;
      if (errorMsg != null && errorMsg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    color: Colors.white,
                    size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _openSectionDetail(EvidenceSection section) {
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => EvidenceSectionDetailView(
          section: section,
          folderIsOpen: widget.folder.isOpen,
          clubSectionId: widget.clubSectionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final folder = widget.folder;
    final filteredSections = _filteredSections;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        final provider = evidenceFolderProvider(widget.clubSectionId);
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // App bar con título
          SliverAppBar(
            automaticallyImplyLeading: false,
            leading: sacAutoBackButton(context),
            pinned: true,
            expandedHeight: 0,
            backgroundColor: c.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'evidence_folder.title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
            ),
            centerTitle: false,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner evaluado / cerrado
                if (!folder.isOpen || folder.isEvaluated)
                  FolderClosedBanner(folder: folder),

                // Banner en evaluación (carpeta abierta pero bajo evaluación)
                if (folder.isOpen && folder.isUnderEvaluation)
                  _UnderEvaluationBanner(folder: folder),

                EvidenceFolderHero(folder: folder),

                EvidenceStatusPills(sections: folder.sections),

                const SizedBox(height: 8),

                // Sections header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'evidence_folder.sections_title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                  ),
                ),

                EvidenceSectionSearchField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  query: _query,
                  onChanged: _handleQueryChanged,
                  onClear: _clearQuery,
                ),
                if (filteredSections.isNotEmpty)
                  const SizedBox(
                    key: ValueKey('evidence-sections-spacing'),
                    height: 8,
                  ),
              ],
            ),
          ),

          // Compact sections grouped inside one paper container.
          if (filteredSections.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  key: const ValueKey('evidence-sections-card'),
                  color: c.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: c.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0;
                          index < filteredSections.length;
                          index++) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: c.divider,
                          ),
                        SectionCard(
                          section: filteredSections[index],
                          folderIsOpen: folder.isOpen,
                          onTap: () =>
                              _openSectionDetail(filteredSections[index]),
                          onSubmit:
                              folder.isOpen && filteredSections[index].canSubmit
                                  ? () => _handleSectionSubmit(
                                        filteredSections[index],
                                      )
                                  : null,
                          isSubmitting: _submittingSectionId ==
                              filteredSections[index].id,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: folder.sections.isEmpty
                ? _EmptySections()
                : _query.trim().isNotEmpty && filteredSections.isEmpty
                    ? const EvidenceSearchEmpty()
                    : const SizedBox(height: 32),
          ),
        ],
      ),
    );
  }
}

// ── Banner bajo evaluación ────────────────────────────────────────────────────

class _UnderEvaluationBanner extends StatelessWidget {
  final EvidenceFolder folder;

  const _UnderEvaluationBanner({required this.folder});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedAnalytics01,
                size: 22,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'evidence_folder.evaluation_banner.title'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'evidence_folder.evaluation_banner.description'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF92400E),
                        height: 1.45,
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptySections extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFolderOpen,
            size: 56,
            color: context.sac.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'evidence_folder.empty_sections'.tr(),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: context.sac.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Empty state: carpeta no disponible (404 de negocio) ──────────────────────

class _NoFolderBody extends ConsumerWidget {
  final String clubSectionId;
  final VoidCallback onBack;

  const _NoFolderBody({
    required this.clubSectionId,
    required this.onBack,
  });

  Future<void> _handleCreate(BuildContext context, WidgetRef ref) async {
    final notifier = ref
        .read(evidenceFolderCreationNotifierProvider(clubSectionId).notifier);
    final created = await notifier.createFolder();

    if (!context.mounted) return;

    final creationState =
        ref.read(evidenceFolderCreationNotifierProvider(clubSectionId));
    if (created) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('evidence_folder.no_folder.create_success'.tr()),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }

    final message = creationState.errorMessage ??
        'evidence_folder.errors.create_folder'.tr();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final canCreate = hasAnyPermission(user, {'evidence_folders:update'});
    final creationState =
        ref.watch(evidenceFolderCreationNotifierProvider(clubSectionId));

    return Column(
      children: [
        AppBar(
          backgroundColor: c.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 22,
              color: c.text,
            ),
            onPressed: onBack,
          ),
          title: Text(
            'evidence_folder.title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
          ),
          centerTitle: false,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: c.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedFolder01,
                        size: 36,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'evidence_folder.no_folder.title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'evidence_folder.no_folder.description1'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                          height: 1.55,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    canCreate
                        ? 'evidence_folder.no_folder.available_hint'.tr()
                        : 'evidence_folder.no_folder.description2'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                          height: 1.55,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (creationState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      creationState.errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                            height: 1.4,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (canCreate) ...[
                    SacButton.primary(
                      text: creationState.isLoading
                          ? 'evidence_folder.no_folder.creating'.tr()
                          : 'evidence_folder.no_folder.create_action'.tr(),
                      icon: HugeIcons.strokeRoundedAdd01,
                      isLoading: creationState.isLoading,
                      onPressed: () => _handleCreate(context, ref),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SacButton.ghost(
                    text: 'common.back'.tr(),
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    onPressed: onBack,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      children: [
        AppBar(
          backgroundColor: c.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 22,
              color: c.text,
            ),
            onPressed: onBack,
          ),
          title: Text(
            'evidence_folder.title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
          ),
          centerTitle: false,
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
                    'evidence_folder.error_load_title'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SacButton.primary(
                    text: 'common.retry'.tr(),
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
