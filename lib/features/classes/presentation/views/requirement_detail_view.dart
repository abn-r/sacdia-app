import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/evidence_staging/staged_file.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/class_requirement.dart';
import '../providers/classes_providers.dart';
import '../utils/status_meta.dart';
import '../widgets/requirement_status_badge.dart';
import '../sheets/requirement_status_history_sheet.dart';

/// Vista de detalle de un requerimiento de clase progresiva — rediseño handoff
/// (Variante E).
///
/// Para estados [RequirementStatus.observado] y [RequirementStatus.rechazado]
/// muestra:
///   - BannerEstado con icono + headline + subtext.
///   - ObservationCard con avatar del instructor + comentario en burbuja.
///   - Lista de archivos adjuntos con badges "En revisión" / "Rechazado".
///   - EmptyFileSlot (botón dashed) para subir archivos.
///   - BigCTA "Reenviar archivos corregidos" (coral).
///
/// Para [RequirementStatus.pendiente] o [RequirementStatus.validado] mantiene
/// el flujo original de EvidenceStagingManager.
class RequirementDetailView extends ConsumerStatefulWidget {
  final ClassRequirement requirement;
  final int classId;

  const RequirementDetailView({
    super.key,
    required this.requirement,
    required this.classId,
  });

  @override
  ConsumerState<RequirementDetailView> createState() =>
      _RequirementDetailViewState();
}

class _RequirementDetailViewState extends ConsumerState<RequirementDetailView> {
  bool _hasUnsavedFiles = false;

  ClassRequirement _liveRequirement(AsyncValue<dynamic> classAsync) {
    return classAsync.whenData((classWithProgress) {
          for (final module in classWithProgress.modules) {
            for (final req in module.requirements) {
              if (req.id == widget.requirement.id) return req;
            }
          }
          return widget.requirement;
        }).valueOrNull ??
        widget.requirement;
  }

  String _resolveModuleName(int moduleId) {
    final classAsync = ref.read(classWithProgressProvider(widget.classId));
    return classAsync.whenData((cp) {
          for (final m in cp.modules) {
            if (m.id == moduleId) return m.name;
          }
          return 'módulo';
        }).valueOrNull ??
        'módulo';
  }

  String _resolveUserInitials() {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user?.name == null || user!.name!.isEmpty) return 'NN';
    final parts = user.name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first
        .substring(0, parts.first.length.clamp(0, 2))
        .toUpperCase();
  }

  String _sanitize(String text, int maxLen) {
    final raw = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return raw.substring(0, raw.length.clamp(0, maxLen));
  }

  String _buildFileNameWithIndex(
      ClassRequirement req, String originalName, int index) {
    final ext = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'bin';
    final moduleName = _resolveModuleName(req.moduleId);
    final sectionName = _sanitize(req.name, 30);
    final initials = _resolveUserInitials();
    return 'evidencia_${index}_${_sanitize(moduleName, 20)}_${sectionName}_$initials.$ext';
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.rejectedColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifierState =
        ref.watch(requirementNotifierProvider(widget.classId));
    final classAsync = ref.watch(classWithProgressProvider(widget.classId));
    final requirement = _liveRequirement(classAsync);
    final canModify = requirement.canUpload;
    final isLoading = notifierState.isLoading;

    // Find module index for eyebrow "X / Y"
    final moduleIndex = _resolveModuleIndex(classAsync, requirement);
    final moduleTotal = _resolveModuleTotal(classAsync, requirement);
    final moduleName = _resolveModuleName(requirement.moduleId);

    ref.listen(
      requirementNotifierProvider(widget.classId),
      (prev, next) {
        if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
          _showErrorSnackbar(context, next.errorMessage!);
        }
      },
    );

    return PopScope(
      canPop: !_hasUnsavedFiles,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('classes.requirement_detail.unsaved_files_title'.tr()),
            content: Text(
              'classes.requirement_detail.unsaved_files_body'.tr(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('classes.requirement_detail.stay_button'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.rejectedColor),
                child: Text('classes.requirement_detail.leave_button'.tr()),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // NavBar
                  _ReqNavBar(
                    onBack: isLoading ? null : () => Navigator.pop(context),
                    onMore: () => showRequirementStatusHistorySheet(
                      context,
                      requirement: requirement,
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Eyebrow + title
                            Text(
                              '${moduleName.toUpperCase()} · ${_fmt2(moduleIndex)} / ${_fmt2(moduleTotal)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink400,
                                letterSpacing: 0.88,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              requirement.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink900,
                                letterSpacing: -0.2,
                                height: 1.25,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Status banner (observed / rejected only)
                            if (requirement.status ==
                                    RequirementStatus.observado ||
                                requirement.status ==
                                    RequirementStatus.rechazado)
                              _BannerEstado(status: requirement.status),

                            // Observation card (observed / rejected)
                            if ((requirement.status ==
                                        RequirementStatus.observado ||
                                    requirement.status ==
                                        RequirementStatus.rechazado) &&
                                _hasInstructorComment(requirement))
                              _ObservationCard(
                                requirement: requirement,
                              ),

                            // Description (for all states when available)
                            if (requirement.description != null &&
                                requirement.description!.isNotEmpty &&
                                requirement.status !=
                                    RequirementStatus.observado &&
                                requirement.status !=
                                    RequirementStatus.rechazado) ...[
                              _DescriptionCard(text: requirement.description!),
                              const SizedBox(height: 16),
                            ],

                            // Status chip (for pending/sent/validated —
                            // open history sheet)
                            if (requirement.status !=
                                    RequirementStatus.observado &&
                                requirement.status !=
                                    RequirementStatus.rechazado) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _StatusChip(
                                  requirement: requirement,
                                  onTap: () =>
                                      showRequirementStatusHistorySheet(
                                    context,
                                    requirement: requirement,
                                  ),
                                ),
                              ),
                            ],

                            // Files section header
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 4, bottom: 10),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ARCHIVOS ADJUNTOS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink400,
                                      letterSpacing: 1.32,
                                    ),
                                  ),
                                  Text(
                                    '${requirement.files.length}/${requirement.maxFiles}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink800,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // For observed/rejected: custom file rows + empty slot + bigCTA
                            if (requirement.status ==
                                    RequirementStatus.observado ||
                                requirement.status ==
                                    RequirementStatus.rechazado) ...[
                              _FileRowsList(
                                requirement: requirement,
                                canModify: canModify,
                                onUploadTap: canModify
                                    ? () => _triggerFilePicker(requirement)
                                    : null,
                              ),

                              const SizedBox(height: 8),

                              // BigCTA
                              if (canModify)
                                _BigCTA(
                                  onTap: () => _handleSubmit(requirement),
                                  isLoading: isLoading,
                                ),
                            ] else ...[
                              // Original EvidenceStagingManager for pending/sent/validated
                              EvidenceStagingManager(
                                embeddedMode: true,
                                existingFiles: requirement.files
                                    .map(StagedFile.fromRequirementEvidence)
                                    .toList(),
                                maxFiles: requirement.maxFiles,
                                isLoading: notifierState.isLoading,
                                onUpload: (xFile, mimeType, onProgress) async {
                                  final success = await ref
                                      .read(requirementNotifierProvider(
                                              widget.classId)
                                          .notifier)
                                      .uploadFile(
                                        requirementId: requirement.id,
                                        pickedFile: xFile,
                                        mimeType: mimeType,
                                        onProgress: onProgress,
                                        skipInvalidation: true,
                                      );
                                  if (!success) {
                                    throw Exception(
                                        tr('classes.errors.upload_failed'));
                                  }
                                },
                                onDeleteRemote: (fileId) async {
                                  await ref
                                      .read(requirementNotifierProvider(
                                              widget.classId)
                                          .notifier)
                                      .deleteFile(
                                        requirementId: requirement.id,
                                        fileId: fileId,
                                      );
                                },
                                onSubmit: () async {
                                  final success = await ref
                                      .read(requirementNotifierProvider(
                                              widget.classId)
                                          .notifier)
                                      .submit(requirement.id);
                                  if (success && mounted) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                                Icons.check_circle_rounded,
                                                color: Colors.white,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                  'classes.requirement_detail.submit_success'
                                                      .tr()),
                                            ),
                                          ],
                                        ),
                                        backgroundColor:
                                            AppColors.validatedColor,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    );
                                    // ignore: use_build_context_synchronously
                                    Navigator.pop(context);
                                  }
                                },
                                fileNameBuilder: (originalName, index) =>
                                    _buildFileNameWithIndex(
                                        requirement, originalName, index),
                                canModify: canModify,
                                onLocalFilesChanged: (hasLocal) =>
                                    setState(() => _hasUnsavedFiles = hasLocal),
                              ),
                            ],

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Loading overlay
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(child: SacLoading()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _hasInstructorComment(ClassRequirement req) {
    return (req.observationComment != null &&
            req.observationComment!.isNotEmpty) ||
        (req.rejectionReason != null && req.rejectionReason!.isNotEmpty);
  }

  int _resolveModuleIndex(
      AsyncValue<dynamic> classAsync, ClassRequirement req) {
    return classAsync.whenData((cp) {
          for (final m in cp.modules) {
            for (int i = 0; i < m.requirements.length; i++) {
              if (m.requirements[i].id == req.id) return i + 1;
            }
          }
          return 1;
        }).valueOrNull ??
        1;
  }

  int _resolveModuleTotal(
      AsyncValue<dynamic> classAsync, ClassRequirement req) {
    return classAsync.whenData((cp) {
          for (final m in cp.modules) {
            if (m.id == req.moduleId) return m.requirements.length;
          }
          return 1;
        }).valueOrNull ??
        1;
  }

  String _fmt2(int n) => n.toString().padLeft(2, '0');

  void _triggerFilePicker(ClassRequirement req) {
    // File picking is handled by EvidenceStagingManager; for observed/rejected
    // we open it via the notifier directly. For now just navigate up to the
    // EvidenceStagingManager path by toggling back to it — this is a placeholder
    // that product can wire to a custom picker when needed.
    // No-op in current implementation.
  }

  Future<void> _handleSubmit(ClassRequirement req) async {
    final success = await ref
        .read(requirementNotifierProvider(widget.classId).notifier)
        .submit(req.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('classes.requirement_detail.submit_success'.tr()),
              ),
            ],
          ),
          backgroundColor: AppColors.validatedColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }
  }
}

// ── NavBar ─────────────────────────────────────────────────────────────────────

class _ReqNavBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onMore;

  const _ReqNavBar({required this.onBack, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      color: AppColors.canvas,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onBack,
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 20,
                  color: AppColors.ink800,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Requerimiento',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.ink900,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onMore,
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreHorizontal,
                  size: 20,
                  color: AppColors.ink600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── BannerEstado ───────────────────────────────────────────────────────────────

class _BannerEstado extends StatelessWidget {
  final RequirementStatus status;

  const _BannerEstado({required this.status});

  @override
  Widget build(BuildContext context) {
    final isObserved = status == RequirementStatus.observado;
    final bg = isObserved ? AppColors.observedBg : AppColors.rejectedBg;
    final borderColor =
        isObserved ? const Color(0xFFFBE7C2) : const Color(0xFFFBC8D0);
    final iconColor =
        isObserved ? AppColors.observedDark : AppColors.rejectedDark;
    final titleColor =
        isObserved ? const Color(0xFF5C4317) : AppColors.rejectedDark;
    final headline =
        isObserved ? 'Requiere correcciones' : 'Documento rechazado';
    final subtext = isObserved
        ? 'Tu instructor solicitó cambios antes de validar'
        : 'Tu instructor pidió que reenvíes este archivo';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Icon bubble
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.paper,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: isObserved
                    ? HugeIcons.strokeRoundedInformationCircle
                    : HugeIcons.strokeRoundedCancel01,
                size: 18,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 12,
                    color: iconColor,
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

// ── ObservationCard ────────────────────────────────────────────────────────────

class _ObservationCard extends StatelessWidget {
  final ClassRequirement requirement;

  const _ObservationCard({required this.requirement});

  @override
  Widget build(BuildContext context) {
    final isObserved = requirement.status == RequirementStatus.observado;
    final instructorName = (isObserved
            ? requirement.observedByName
            : requirement.rejectedByName) ??
        'Instructor';
    final comment = (isObserved
            ? requirement.observationComment
            : requirement.rejectionReason) ??
        '';
    final timestamp =
        isObserved ? requirement.observedAt : requirement.rejectedAt;

    final initials = _initials(instructorName);
    final avatarBg = isObserved ? AppColors.coral100 : AppColors.rejectedBg;
    final avatarText = isObserved ? AppColors.coral700 : AppColors.rejectedDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink150),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name + timestamp
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: avatarText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instructorName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink800,
                      ),
                    ),
                    Text(
                      timestamp != null
                          ? 'Instructor · ${_timeAgo(timestamp)}'
                          : 'Instructor',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Comment bubble
          if (comment.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"$comment"',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.ink700,
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 1)
      return 'hace ${diff.inDays} día${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours >= 1)
      return 'hace ${diff.inHours} hora${diff.inHours == 1 ? '' : 's'}';
    if (diff.inMinutes >= 1) {
      return 'hace ${diff.inMinutes} minuto${diff.inMinutes == 1 ? '' : 's'}';
    }
    return 'hace un momento';
  }
}

// ── FileRowsList ───────────────────────────────────────────────────────────────

class _FileRowsList extends StatelessWidget {
  final ClassRequirement requirement;
  final bool canModify;
  final VoidCallback? onUploadTap;

  const _FileRowsList({
    required this.requirement,
    required this.canModify,
    this.onUploadTap,
  });

  @override
  Widget build(BuildContext context) {
    final isObserved = requirement.status == RequirementStatus.observado;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...requirement.files.map((file) => _FileRow(
              fileName: file.fileName,
              uploadedAt: file.uploadedAt,
              isObservedContext: isObserved,
            )),

        // Empty file slot if canModify
        if (canModify) _EmptyFileSlot(onTap: onUploadTap ?? () {}),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  final String fileName;
  final DateTime uploadedAt;
  final bool isObservedContext;

  const _FileRow({
    required this.fileName,
    required this.uploadedAt,
    required this.isObservedContext,
  });

  @override
  Widget build(BuildContext context) {
    // In observed context, files show "En revisión" badge (sentBg/sentDark).
    // In rejected context, files show "Rechazado" badge (observedBg/observedDark).
    // Note: the handoff uses "observedBg" yellow for rejected file icon bg — we
    // follow the reference exactly.
    final iconBg = isObservedContext ? AppColors.sentBg : AppColors.observedBg;
    final iconColor =
        isObservedContext ? AppColors.sentDark : AppColors.observedDark;
    final badgeLabel = isObservedContext ? 'En revisión' : 'Rechazado';
    final badgeBg = isObservedContext ? AppColors.sentBg : AppColors.observedBg;
    final badgeColor =
        isObservedContext ? AppColors.sentDark : AppColors.observedDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink150),
      ),
      child: Row(
        children: [
          // Icon square
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFile01,
                size: 18,
                color: iconColor,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Filename + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _timeAgo(uploadedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Badge pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 1)
      return 'Hace ${diff.inDays} día${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours >= 1)
      return 'Hace ${diff.inHours} hora${diff.inHours == 1 ? '' : 's'}';
    return 'Hace un momento';
  }
}

class _EmptyFileSlot extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyFileSlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.ink300,
        strokeWidth: 1.5,
        radius: 12,
        dashLength: 6,
        gapLength: 4,
      ),
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.ink100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAdd01,
                      size: 18,
                      color: AppColors.ink400,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Subir archivo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end.toDouble()),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}

// ── BigCTA ─────────────────────────────────────────────────────────────────────

class _BigCTA extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _BigCTA({required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: isLoading
              ? AppColors.coral500.withValues(alpha: 0.6)
              : AppColors.coral500,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.coral500.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              HugeIcon(
                icon: HugeIcons.strokeRoundedUpload01,
                size: 16,
                color: Colors.white,
              ),
            const SizedBox(width: 8),
            const Text(
              'Reenviar archivos corregidos',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Description card (for non-observed/rejected states) ───────────────────────

class _DescriptionCard extends StatelessWidget {
  final String text;

  const _DescriptionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink150),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          color: AppColors.ink700,
          height: 1.5,
        ),
      ),
    );
  }
}

// ── Status chip (for pending/sent/validated) ──────────────────────────────────

class _StatusChip extends StatelessWidget {
  final ClassRequirement requirement;
  final VoidCallback onTap;

  const _StatusChip({required this.requirement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = StatusMeta.of(requirement.status);

    return Semantics(
      button: true,
      label: 'Estado: ${meta.label}. Toca para ver historial.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: meta.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: meta.color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RequirementStatusBadge(status: requirement.status),
              const Spacer(),
              HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                size: 15,
                color: AppColors.ink400,
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}
