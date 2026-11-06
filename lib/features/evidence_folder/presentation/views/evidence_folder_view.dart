import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/errors/exceptions.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/evidence_folder_loading_skeleton.dart';
import '../widgets/evidence_folder_summary.dart';
import '../../domain/entities/evidence_folder.dart';
import '../../domain/entities/evidence_section.dart';
import '../providers/evidence_folder_providers.dart';
import '../widgets/section_row.dart';
import '../widgets/section_status_style.dart';
import 'evidence_section_detail_view.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

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
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'evidence_folder.title'.tr(),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: folderAsync.when(
              loading: () => Padding(
                padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
                child: const EvidenceFolderLoadingSkeleton(),
              ),
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
                return SacErrorState(
                  title: 'evidence_folder.error_load_title'.tr(),
                  message: userErrorMessage(error),
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.all(32),
                  ),
                  onRetry: () =>
                      ref.invalidate(evidenceFolderProvider(clubSectionId)),
                );
              },
            ),
          ),
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
      HapticFeedback.mediumImpact();
      SacSnackBar.show(
        context,
        'evidence_folder.submit_success'.tr(namedArgs: {
          'sectionName': section.name,
        }),
        isSuccess: true,
      );
    } else {
      final errorMsg = ref
          .read(evidenceSectionNotifierProvider(widget.clubSectionId))
          .errorMessage;
      if (errorMsg != null && errorMsg.isNotEmpty) {
        SacSnackBar.show(context, errorMsg, isError: true);
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
          requiresUnion: widget.folder.requiresUnionConfirmation,
        ),
      ),
    );
  }

  Widget _row(EvidenceSection section) {
    final folder = widget.folder;
    return EvidenceSectionRow(
      section: section,
      onTap: () => _openSectionDetail(section),
      onSubmit: folder.isOpen && section.canSubmit
          ? () => _handleSectionSubmit(section)
          : null,
      isSubmitting: _submittingSectionId == section.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final folder = widget.folder;
    final sections = folder.sections;

    // What needs the club first: rejected, then not sent; then what waits on
    // someone else; validated last. An evaluated folder is one plain list.
    final groups = <(String, String, List<EvidenceSection>)>[];
    if (folder.isEvaluated) {
      groups.add(('all', 'evidence_folder.groups.all'.tr(), sections));
    } else {
      final attention = [
        ...sections.where((s) => s.status == EvidenceSectionStatus.rejected),
        ...sections.where((s) => s.status == EvidenceSectionStatus.pending),
      ];
      final review = [
        ...sections
            .where((s) => s.status == EvidenceSectionStatus.preapprovedLf),
        ...sections.where((s) => s.status == EvidenceSectionStatus.submitted),
      ];
      final validated = sections
          .where((s) => s.status.group == EvidenceStatusGroup.validated)
          .toList();
      if (attention.isNotEmpty) {
        groups.add(
            ('attention', 'evidence_folder.groups.attention'.tr(), attention));
      }
      if (review.isNotEmpty) {
        groups.add(('review', 'evidence_folder.groups.review'.tr(), review));
      }
      if (validated.isNotEmpty) {
        groups.add(
            ('validated', 'evidence_folder.groups.validated'.tr(), validated));
      }
    }

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: () async {
        final provider = evidenceFolderProvider(widget.clubSectionId);
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: SacTopBar.frostedInset(context)),
          ),
          SliverToBoxAdapter(child: EvidenceFolderSummary(folder: folder)),
          if (sections.isEmpty)
            SliverToBoxAdapter(
              child: SacEmptyState.inline(
                title: 'evidence_folder.empty_sections'.tr(),
                icon: HugeIcons.strokeRoundedFolderOpen,
              ),
            )
          else
            for (final (id, label, items) in groups)
              SliverToBoxAdapter(
                child: EvidenceSectionGroup(
                  key: ValueKey('evidence-group-$id'),
                  label: label,
                  children: [for (final s in items) _row(s)],
                ),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
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

    // On failure the message is rendered inline under the description; a
    // snackbar on top would show the same error twice.
    if (!created || !context.mounted) return;

    SacSnackBar.show(context, 'evidence_folder.no_folder.create_success'.tr(),
        isSuccess: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider).value;
    final canCreate = hasAnyPermission(user, {'evidence_folders:update'});
    final creationState =
        ref.watch(evidenceFolderCreationNotifierProvider(clubSectionId));

    // Only offer creation when a published template exists for the section's
    // club type and year; otherwise POST fails with
    // ANNUAL_FOLDER_TEMPLATE_NO_MATCH. A failed check (null) does not block
    // the action — the backend still validates on create.
    final availabilityAsync = canCreate
        ? ref.watch(evidenceFolderTemplateAvailabilityProvider(clubSectionId))
        : null;
    final isCheckingTemplate = availabilityAsync?.isLoading ?? false;
    final availability = availabilityAsync?.value;
    final templateMissing = availability != null && !availability.isAvailable;
    final showCreate = canCreate && !isCheckingTemplate && !templateMissing;

    final String? hint;
    if (!canCreate) {
      hint = 'evidence_folder.no_folder.description2'.tr();
    } else if (isCheckingTemplate) {
      hint = null;
    } else if (templateMissing) {
      final clubType = availability.clubTypeName;
      final year = availability.yearLabel;
      hint = clubType != null && year != null
          ? 'evidence_folder.no_folder.no_template_hint'
              .tr(namedArgs: {'clubType': clubType, 'year': year})
          : 'evidence_folder.no_folder.no_template_hint_generic'.tr();
    } else if (availability != null) {
      hint = 'evidence_folder.no_folder.available_hint'.tr();
    } else {
      hint = 'evidence_folder.no_folder.create_hint'.tr();
    }

    return Padding(
      padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
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
              if (hint != null) ...[
                const SizedBox(height: 6),
                Text(
                  hint,
                  key: const ValueKey('evidence-folder-no-folder-hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        height: 1.55,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              // When the template turns out to be missing the hint already
              // explains it; repeating the create error would duplicate it.
              if (creationState.errorMessage != null && !templateMissing) ...[
                const SizedBox(height: 12),
                Text(
                  creationState.errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.onErrorContainer,
                        height: 1.4,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              if (isCheckingTemplate) ...[
                const SacLoadingSmall(),
                const SizedBox(height: 12),
              ],
              if (showCreate) ...[
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
    );
  }
}
