import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/requirement_evidence.dart';
import '../providers/honors_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const int _kMaxPerType = 3;
const int _kMaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

// ── Public helper to open the sheet ──────────────────────────────────────────

/// Shows the [EvidenceUploadSheet] as a modal bottom sheet.
///
/// Call this from any widget that has a [BuildContext] and knows the
/// `userId`, `honorId`, and `requirementId`.
Future<void> showEvidenceUploadSheet({
  required BuildContext context,
  required String userId,
  required int honorId,
  required int requirementId,
  required Color categoryColor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EvidenceUploadSheet(
      userId: userId,
      honorId: honorId,
      requirementId: requirementId,
      categoryColor: categoryColor,
    ),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

/// Bottom sheet for managing requirement evidence (photos, files, links).
///
/// Uses three tabs:
///   - Fotos (IMAGE) — camera or gallery, max [_kMaxPerType]
///   - Archivos (FILE) — any file, max [_kMaxPerType]
///   - Enlaces (LINK) — URL input, max [_kMaxPerType]
///
/// Reads evidences reactively via [requirementEvidenceProvider] and mutates
/// them via [RequirementEvidenceNotifier].
class EvidenceUploadSheet extends ConsumerStatefulWidget {
  final String userId;
  final int honorId;
  final int requirementId;
  final Color categoryColor;

  const EvidenceUploadSheet({
    super.key,
    required this.userId,
    required this.honorId,
    required this.requirementId,
    required this.categoryColor,
  });

  @override
  ConsumerState<EvidenceUploadSheet> createState() =>
      _EvidenceUploadSheetState();
}

class _EvidenceUploadSheetState extends ConsumerState<EvidenceUploadSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _linkController = TextEditingController();
  bool _isOperating = false;

  RequirementEvidenceParams get _params => (
        userId: widget.userId,
        honorId: widget.honorId,
        requirementId: widget.requirementId,
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<RequirementEvidence> _byType(
    List<RequirementEvidence> all,
    EvidenceType type,
  ) =>
      all.where((e) => e.evidenceType == type).toList();

  void _setOperating(bool value) {
    if (mounted) setState(() => _isOperating = value);
  }

  Future<void> _showError(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showSuccess(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Upload a file (image or document) ────────────────────────────────────

  Future<void> _uploadFile(File file, EvidenceType evidenceType) async {
    final fileSize = await file.length();
    if (fileSize > _kMaxFileSizeBytes) {
      await _showError('El archivo excede el límite de 10 MB');
      return;
    }

    _setOperating(true);

    final notifier = ref.read(
      requirementEvidenceNotifierProvider(_params).notifier,
    );

    final success = await notifier.uploadEvidence(
      userId: widget.userId,
      honorId: widget.honorId,
      requirementId: widget.requirementId,
      file: file,
    );

    _setOperating(false);

    if (success) {
      await _showSuccess('Evidencia subida correctamente');
    } else {
      await _showError('Error al subir la evidencia');
    }
  }

  // ── Image pickers ─────────────────────────────────────────────────────────

  Future<void> _pickFromCamera(List<RequirementEvidence> existing) async {
    if (_byType(existing, EvidenceType.image).length >= _kMaxPerType) {
      await _showError('Máximo $_kMaxPerType fotos por requisito');
      return;
    }

    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      await _uploadFile(File(image.path), EvidenceType.image);
    }
  }

  Future<void> _pickFromGallery(List<RequirementEvidence> existing) async {
    final images = _byType(existing, EvidenceType.image);
    if (images.length >= _kMaxPerType) {
      await _showError('Máximo $_kMaxPerType fotos por requisito');
      return;
    }

    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
      limit: _kMaxPerType - images.length,
    );
    for (final img in picked) {
      if (!mounted) return;
      await _uploadFile(File(img.path), EvidenceType.image);
    }
  }

  // ── File picker ───────────────────────────────────────────────────────────

  Future<void> _pickFile(List<RequirementEvidence> existing) async {
    if (_byType(existing, EvidenceType.file).length >= _kMaxPerType) {
      await _showError('Máximo $_kMaxPerType archivos por requisito');
      return;
    }

    HapticFeedback.selectionClick();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      if (f.path != null) {
        await _uploadFile(File(f.path!), EvidenceType.file);
      }
    }
  }

  // ── Link add ──────────────────────────────────────────────────────────────

  Future<void> _addLink(List<RequirementEvidence> existing) async {
    final url = _linkController.text.trim();
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      await _showError('Ingresá una URL válida (ej. https://...)');
      return;
    }

    if (_byType(existing, EvidenceType.link).length >= _kMaxPerType) {
      await _showError('Máximo $_kMaxPerType enlaces por requisito');
      return;
    }

    _setOperating(true);

    final notifier = ref.read(
      requirementEvidenceNotifierProvider(_params).notifier,
    );

    final success = await notifier.addLink(
      userId: widget.userId,
      honorId: widget.honorId,
      requirementId: widget.requirementId,
      url: url,
    );

    _setOperating(false);

    if (success) {
      _linkController.clear();
      await _showSuccess('Enlace agregado');
    } else {
      await _showError('Error al agregar el enlace');
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteEvidence(int evidenceId) async {
    _setOperating(true);

    final notifier = ref.read(
      requirementEvidenceNotifierProvider(_params).notifier,
    );

    final success = await notifier.deleteEvidence(
      userId: widget.userId,
      honorId: widget.honorId,
      requirementId: widget.requirementId,
      evidenceId: evidenceId,
    );

    _setOperating(false);

    if (!success && mounted) {
      await _showError('Error al eliminar la evidencia');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final evidenceAsync =
        ref.watch(requirementEvidenceProvider(_params));

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.78,
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.sac.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                Icon(
                  Icons.attach_file_rounded,
                  size: 20,
                  color: widget.categoryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Evidencias',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.sac.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.sac.textTertiary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: widget.categoryColor,
            unselectedLabelColor: context.sac.textTertiary,
            indicatorColor: widget.categoryColor,
            indicatorWeight: 2,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: evidenceAsync.when(
              data: (evidences) => [
                Tab(
                  text:
                      'Fotos (${_byType(evidences, EvidenceType.image).length}/$_kMaxPerType)',
                ),
                Tab(
                  text:
                      'Archivos (${_byType(evidences, EvidenceType.file).length}/$_kMaxPerType)',
                ),
                Tab(
                  text:
                      'Enlaces (${_byType(evidences, EvidenceType.link).length}/$_kMaxPerType)',
                ),
              ],
              loading: () => const [
                Tab(text: 'Fotos'),
                Tab(text: 'Archivos'),
                Tab(text: 'Enlaces'),
              ],
              error: (_, __) => const [
                Tab(text: 'Fotos'),
                Tab(text: 'Archivos'),
                Tab(text: 'Enlaces'),
              ],
            ),
          ),

          Divider(height: 1, color: context.sac.divider),

          // Tab view
          Expanded(
            child: Stack(
              children: [
                evidenceAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'Error al cargar evidencias',
                      style: TextStyle(color: context.sac.textSecondary),
                    ),
                  ),
                  data: (evidences) => TabBarView(
                    controller: _tabController,
                    children: [
                      _PhotoTab(
                        images: _byType(evidences, EvidenceType.image),
                        onPickCamera: () =>
                            _pickFromCamera(evidences),
                        onPickGallery: () =>
                            _pickFromGallery(evidences),
                        onDelete: _deleteEvidence,
                        categoryColor: widget.categoryColor,
                      ),
                      _FileTab(
                        files: _byType(evidences, EvidenceType.file),
                        onPickFile: () => _pickFile(evidences),
                        onDelete: _deleteEvidence,
                        categoryColor: widget.categoryColor,
                      ),
                      _LinkTab(
                        links: _byType(evidences, EvidenceType.link),
                        controller: _linkController,
                        onAdd: () => _addLink(evidences),
                        onDelete: _deleteEvidence,
                        categoryColor: widget.categoryColor,
                      ),
                    ],
                  ),
                ),

                // Operation overlay
                if (_isOperating)
                  Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Photo Tab ─────────────────────────────────────────────────────────────────

class _PhotoTab extends StatelessWidget {
  final List<RequirementEvidence> images;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final Future<void> Function(int evidenceId) onDelete;
  final Color categoryColor;

  const _PhotoTab({
    required this.images,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onDelete,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        // Action buttons
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.camera_alt_rounded,
                label: 'Cámara',
                color: categoryColor,
                onTap: images.length >= _kMaxPerType ? null : onPickCamera,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.photo_library_rounded,
                label: 'Galería',
                color: categoryColor,
                onTap: images.length >= _kMaxPerType ? null : onPickGallery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (images.isEmpty)
          _EmptySection(label: 'Sin fotos adjuntas', icon: Icons.photo_outlined)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: images.length,
            itemBuilder: (_, i) => _ImageTile(
              evidence: images[i],
              onDelete: onDelete,
            ),
          ),
      ],
    );
  }
}

// ── File Tab ──────────────────────────────────────────────────────────────────

class _FileTab extends StatelessWidget {
  final List<RequirementEvidence> files;
  final VoidCallback onPickFile;
  final Future<void> Function(int evidenceId) onDelete;
  final Color categoryColor;

  const _FileTab({
    required this.files,
    required this.onPickFile,
    required this.onDelete,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        _ActionButton(
          icon: Icons.upload_file_rounded,
          label: 'Seleccionar archivo',
          color: categoryColor,
          onTap: files.length >= _kMaxPerType ? null : onPickFile,
        ),
        const SizedBox(height: 16),
        if (files.isEmpty)
          _EmptySection(
              label: 'Sin archivos adjuntos', icon: Icons.folder_open_rounded)
        else
          ...files.map(
            (f) => _FileTile(evidence: f, onDelete: onDelete),
          ),
      ],
    );
  }
}

// ── Link Tab ──────────────────────────────────────────────────────────────────

class _LinkTab extends StatelessWidget {
  final List<RequirementEvidence> links;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final Future<void> Function(int evidenceId) onDelete;
  final Color categoryColor;

  const _LinkTab({
    required this.links,
    required this.controller,
    required this.onAdd,
    required this.onDelete,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = links.length < _kMaxPerType;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        // URL input row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: canAdd,
                style: TextStyle(fontSize: 13, color: context.sac.text),
                decoration: InputDecoration(
                  hintText: 'https://...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: context.sac.textTertiary,
                  ),
                  prefixIcon: Icon(
                    Icons.link_rounded,
                    color: canAdd ? categoryColor : context.sac.textTertiary,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.sac.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.sac.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: categoryColor, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => canAdd ? onAdd() : null,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: canAdd ? onAdd : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: context.sac.surfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text(
                  'Agregar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (links.isEmpty)
          _EmptySection(
              label: 'Sin enlaces adjuntos', icon: Icons.link_off_rounded)
        else
          ...links.map(
            (l) => _LinkTile(evidence: l, onDelete: onDelete),
          ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Reusable icon-button for triggering a pick action.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: disabled
              ? context.sac.surfaceVariant
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled ? context.sac.border : color.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: disabled ? context.sac.textTertiary : color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: disabled ? context.sac.textTertiary : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state placeholder for a tab section.
class _EmptySection extends StatelessWidget {
  final String label;
  final IconData icon;

  const _EmptySection({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 36, color: context.sac.textTertiary),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: context.sac.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// A 1:1 image thumbnail in the photo grid with a delete overlay.
class _ImageTile extends StatelessWidget {
  final RequirementEvidence evidence;
  final Future<void> Function(int evidenceId) onDelete;

  const _ImageTile({required this.evidence, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: evidence.url,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              color: AppColors.lightSurfaceVariant,
              child: const Icon(Icons.broken_image_rounded, size: 24),
            ),
          ),
        ),

        // Delete badge
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => onDelete(evidence.id),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A list tile for a file evidence with filename and delete button.
class _FileTile extends StatelessWidget {
  final RequirementEvidence evidence;
  final Future<void> Function(int evidenceId) onDelete;

  const _FileTile({required this.evidence, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.sac.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 20,
              color: context.sac.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                evidence.filename ?? evidence.url.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: context.sac.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onDelete(evidence.id),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list tile for a link evidence with tappable URL and delete button.
class _LinkTile extends StatelessWidget {
  final RequirementEvidence evidence;
  final Future<void> Function(int evidenceId) onDelete;

  const _LinkTile({required this.evidence, required this.onDelete});

  Future<void> _launch() async {
    final uri = Uri.tryParse(evidence.url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.sac.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.link_rounded,
              size: 20,
              color: AppColors.sacBlue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _launch,
                child: Text(
                  evidence.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.sacBlue,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.sacBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onDelete(evidence.id),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
