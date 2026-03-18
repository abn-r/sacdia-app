import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';
import '../../domain/usecases/get_honors.dart';
import '../../domain/usecases/register_user_honor.dart';
import '../providers/honors_providers.dart';

// ── Label helpers ─────────────────────────────────────────────────────────────

String _approvalLabel(int level) {
  switch (level) {
    case 1:
      return 'General';
    case 2:
      return 'Avanzado';
    case 3:
      return 'Master';
    default:
      return 'Nivel $level';
  }
}

String _skillLevelLabel(int level) {
  switch (level) {
    case 1:
      return 'Básico';
    case 2:
      return 'Intermedio';
    case 3:
      return 'Avanzado';
    default:
      return 'Nivel $level';
  }
}

Color _skillLevelColor(int level) {
  switch (level) {
    case 1:
      return AppColors.secondary;
    case 2:
      return AppColors.accent;
    case 3:
      return AppColors.primary;
    default:
      return AppColors.primary;
  }
}

// ── Main View ─────────────────────────────────────────────────────────────────

/// Vista de detalle de honor
///
/// Muestra información completa del honor: imagen hero, descripción,
/// material PDF, y formulario de registro de completación.
///
/// Si se pasa [initialHonor], los datos se usan directamente sin
/// llamar al provider, evitando una petición redundante a la API.
class HonorDetailView extends ConsumerWidget {
  final int honorId;
  final Honor? initialHonor;

  const HonorDetailView({
    super.key,
    required this.honorId,
    this.initialHonor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialHonor != null) {
      return _HonorDetailContent(honor: initialHonor!, honorId: honorId);
    }

    final honorAsync = ref.watch(honorsProvider(const GetHonorsParams()));
    return honorAsync.when(
      data: (honors) {
        try {
          final honor = honors.firstWhere((h) => h.id == honorId);
          return _HonorDetailContent(honor: honor, honorId: honorId);
        } catch (_) {
          return _ErrorScaffold(onRetry: () => ref.invalidate(honorsProvider));
        }
      },
      loading: () => const Scaffold(body: Center(child: SacLoading())),
      error: (_, __) =>
          _ErrorScaffold(onRetry: () => ref.invalidate(honorsProvider)),
    );
  }
}

// ── Detail Content ────────────────────────────────────────────────────────────

class _HonorDetailContent extends ConsumerWidget {
  final Honor honor;
  final int honorId;

  const _HonorDetailContent({required this.honor, required this.honorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userHonorAsync = ref.watch(userHonorForHonorProvider(honorId));

    return Scaffold(
      backgroundColor: context.sac.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero SliverAppBar ──────────────────────────────────────
          _HeroAppBar(honor: honor),

          // ── Body ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skill / Approval chips row
                  _InfoChipsRow(honor: honor),
                  const SizedBox(height: 24),

                  // Description
                  if (honor.description != null &&
                      honor.description!.isNotEmpty) ...[
                    _SectionTitle(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      label: 'Descripción',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      honor.description!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.65,
                        color: context.sac.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Meta info row (year, clubType)
                  _MetaInfoRow(honor: honor),
                  const SizedBox(height: 24),

                  // Material PDF card
                  if (honor.materialUrl != null &&
                      honor.materialUrl!.isNotEmpty) ...[
                    _MaterialCard(materialUrl: honor.materialUrl!),
                    const SizedBox(height: 28),
                  ],

                  // Divider before registration section
                  Divider(color: context.sac.border, thickness: 1),
                  const SizedBox(height: 24),

                  // Registration section
                  userHonorAsync.when(
                    data: (userHonor) => userHonor != null
                        ? _AlreadyRegisteredCard(userHonor: userHonor)
                        : _RegistrationSection(honor: honor),
                    loading: () => const Center(child: SacLoading()),
                    error: (_, __) => _RegistrationSection(honor: honor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero AppBar ───────────────────────────────────────────────────────────────

class _HeroAppBar extends StatelessWidget {
  final Honor honor;

  const _HeroAppBar({required this.honor});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppColors.sacBlack,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.sacBlack,
                    Color(0xFF2A4A6A),
                  ],
                ),
              ),
            ),
            // Honor image
            if (honor.imageUrl != null && honor.imageUrl!.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: honor.imageUrl!,
                  fit: BoxFit.cover,
                  color: Colors.white.withValues(alpha: 0.12),
                  colorBlendMode: BlendMode.modulate,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Honor badge image
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: honor.imageUrl != null &&
                              honor.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: CachedNetworkImage(
                                imageUrl: honor.imageUrl!,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => HugeIcon(
                                  icon: HugeIcons.strokeRoundedAward01,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : HugeIcon(
                              icon: HugeIcons.strokeRoundedAward01,
                              size: 48,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Honor name
                    Text(
                      honor.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Chips Row ────────────────────────────────────────────────────────────

class _InfoChipsRow extends StatelessWidget {
  final Honor honor;

  const _InfoChipsRow({required this.honor});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (honor.skillLevel != null)
          _InfoChip(
            label: _skillLevelLabel(honor.skillLevel!),
            color: _skillLevelColor(honor.skillLevel!),
            icon: HugeIcons.strokeRoundedStar,
          ),
        _InfoChip(
          label: _approvalLabel(honor.approval),
          color: AppColors.sacBlue,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        ),
        if (honor.year != null && honor.year!.isNotEmpty)
          _InfoChip(
            label: honor.year!,
            color: context.sac.textSecondary,
            icon: HugeIcons.strokeRoundedCalendar03,
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final dynamic icon;

  const _InfoChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final dynamic icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
        ),
      ],
    );
  }
}

// ── Meta Info Row ─────────────────────────────────────────────────────────────

class _MetaInfoRow extends StatelessWidget {
  final Honor honor;

  const _MetaInfoRow({required this.honor});

  @override
  Widget build(BuildContext context) {
    return SacCard(
      backgroundColor: context.sac.surfaceVariant,
      child: Row(
        children: [
          _MetaItem(
            icon: HugeIcons.strokeRoundedUserGroup,
            label: 'Tipo de club',
            value: honor.clubTypeId == 1
                ? 'Conquistadores'
                : honor.clubTypeId == 2
                    ? 'Aventureros'
                    : 'Club ${honor.clubTypeId}',
          ),
          Container(
            width: 1,
            height: 40,
            color: context.sac.border,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _MetaItem(
            icon: HugeIcons.strokeRoundedCheckmarkBadge01,
            label: 'Aprobación',
            value: _approvalLabel(honor.approval),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final dynamic icon;
  final String label;
  final String value;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.sac.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.sac.text,
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

// ── Material Card ─────────────────────────────────────────────────────────────

class _MaterialCard extends StatefulWidget {
  final String materialUrl;

  const _MaterialCard({required this.materialUrl});

  @override
  State<_MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends State<_MaterialCard> {
  bool _isLaunching = false;

  Future<void> _openMaterial() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    try {
      final uri = Uri.parse(widget.materialUrl);
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo abrir el material'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al abrir el material PDF'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.sac.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // PDF icon container
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Material de estudio',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.sac.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Abre el documento PDF con los requisitos y guía de estudio.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.sac.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Open button
                  GestureDetector(
                    onTap: _openMaterial,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isLaunching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.open_in_new_rounded,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  'Abrir',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            // Accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Already Registered Card ───────────────────────────────────────────────────

class _AlreadyRegisteredCard extends StatelessWidget {
  final UserHonor userHonor;

  const _AlreadyRegisteredCard({required this.userHonor});

  @override
  Widget build(BuildContext context) {
    final isValidated = userHonor.validate;
    final statusColor =
        isValidated ? AppColors.secondary : AppColors.accentDark;
    final statusBg = isValidated ? AppColors.secondaryLight : AppColors.accentLight;
    final statusLabel = isValidated ? 'Validado' : 'En revisión';
    final statusIcon = isValidated
        ? HugeIcons.strokeRoundedCheckmarkCircle02
        : HugeIcons.strokeRoundedClock01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: HugeIcons.strokeRoundedAward01,
          label: 'Mi registro',
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge
              Row(
                children: [
                  HugeIcon(icon: statusIcon, size: 20, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Date
              _RegistrationDetailRow(
                label: 'Fecha de completación',
                value: DateFormat('dd/MM/yyyy').format(userHonor.date),
              ),
              if (userHonor.certificate.isNotEmpty) ...[
                const SizedBox(height: 6),
                _RegistrationDetailRow(
                  label: 'Certificado',
                  value: userHonor.certificate,
                ),
              ],
              if (userHonor.images.isNotEmpty) ...[
                const SizedBox(height: 6),
                _RegistrationDetailRow(
                  label: 'Evidencias',
                  value: '${userHonor.images.length} imagen(es)',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RegistrationDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _RegistrationDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: context.sac.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: context.sac.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Registration Section ──────────────────────────────────────────────────────

class _RegistrationSection extends ConsumerStatefulWidget {
  final Honor honor;

  const _RegistrationSection({required this.honor});

  @override
  ConsumerState<_RegistrationSection> createState() =>
      _RegistrationSectionState();
}

class _RegistrationSectionState extends ConsumerState<_RegistrationSection> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  final _certificateController = TextEditingController();
  final _documentController = TextEditingController();
  List<XFile> _proofImages = [];
  bool _isExpanded = false;

  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _certificateController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _imagePicker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) {
        setState(() {
          _proofImages = [..._proofImages, ...picked];
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudieron seleccionar imágenes'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _proofImages = List.from(_proofImages)..removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final authState = ref.read(authNotifierProvider);
    final userId = authState.value?.id;
    if (userId == null) return;

    // In a real app with file upload, images would be uploaded first and
    // the returned URLs passed here. For now, paths are sent as-is.
    final imageUrls = _proofImages.map((f) => f.path).toList();

    final params = RegisterUserHonorParams(
      userId: userId,
      honorId: widget.honor.id,
      date: _selectedDate,
      images: imageUrls,
      certificate: _certificateController.text.trim(),
      document: _documentController.text.trim().isEmpty
          ? null
          : _documentController.text.trim(),
    );

    final success = await ref
        .read(honorRegistrationNotifierProvider.notifier)
        .register(params);

    if (success && mounted) {
      HapticFeedback.heavyImpact();
      ref.invalidate(userHonorsProvider);
      ref.invalidate(userHonorForHonorProvider(widget.honor.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Especialidad registrada exitosamente'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final registrationState = ref.watch(honorRegistrationNotifierProvider);
    final isLoading =
        registrationState.status == HonorRegistrationStatus.loading;
    final hasError =
        registrationState.status == HonorRegistrationStatus.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with expand toggle
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Row(
            children: [
              _SectionTitle(
                icon: HugeIcons.strokeRoundedPencilEdit02,
                label: 'Registrar especialidad',
              ),
              const Spacer(),
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Completa el formulario para registrar la finalización de esta especialidad. Un administrador la revisará.',
          style: TextStyle(
            fontSize: 13,
            color: context.sac.textSecondary,
            height: 1.4,
          ),
        ),

        // Error banner
        if (hasError && registrationState.errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    registrationState.errorMessage!,
                    style: const TextStyle(
                      color: AppColors.errorDark,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Expandable form
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildForm(context, isLoading),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 280),
          sizeCurve: Curves.easeInOut,
        ),

        // If collapsed, show expand button
        if (!_isExpanded) ...[
          const SizedBox(height: 16),
          SacButton.primary(
            text: 'Registrar completación',
            icon: HugeIcons.strokeRoundedAdd01,
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = true);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildForm(BuildContext context, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // ── Date picker ────────────────────────────────────────────
          _FormFieldLabel(label: 'Fecha de completación *'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.sac.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.sac.border),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('dd / MM / yyyy').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.sac.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Cambiar',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Certificate field ──────────────────────────────────────
          _FormFieldLabel(label: 'Número / referencia de certificado'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _certificateController,
            decoration: InputDecoration(
              hintText: 'Ej: CERT-2025-001',
              filled: true,
              fillColor: context.sac.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.sac.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.sac.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCertificate01,
                  size: 18,
                  color: context.sac.textSecondary,
                ),
              ),
            ),
            style: TextStyle(color: context.sac.text, fontSize: 15),
          ),
          const SizedBox(height: 16),

          // ── Document URL (optional) ────────────────────────────────
          _FormFieldLabel(label: 'URL de documento (opcional)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _documentController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://...',
              filled: true,
              fillColor: context.sac.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.sac.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.sac.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedLink01,
                  size: 18,
                  color: context.sac.textSecondary,
                ),
              ),
            ),
            style: TextStyle(color: context.sac.text, fontSize: 15),
          ),
          const SizedBox(height: 20),

          // ── Proof images ───────────────────────────────────────────
          _FormFieldLabel(label: 'Imágenes de evidencia'),
          const SizedBox(height: 6),
          Text(
            'Agrega fotos que demuestren que completaste la especialidad.',
            style: TextStyle(
              fontSize: 12,
              color: context.sac.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Image thumbnails + add button
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Existing images
              ..._proofImages.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return _ImageThumb(
                  file: file,
                  onRemove: () => _removeImage(index),
                );
              }),
              // Add button
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                        size: 22,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Agregar',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Submit button ──────────────────────────────────────────
          SacButton.success(
            text: 'Enviar registro',
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            isLoading: isLoading,
            isEnabled: !isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'El registro estara pendiente de validacion por un administrador.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: context.sac.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Form Field Label ──────────────────────────────────────────────────────────

class _FormFieldLabel extends StatelessWidget {
  final String label;

  const _FormFieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.sac.textSecondary,
      ),
    );
  }
}

// ── Image Thumb ───────────────────────────────────────────────────────────────

class _ImageThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _ImageThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(file.path),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 72,
              height: 72,
              color: AppColors.primaryLight,
              child: const Icon(Icons.image, color: AppColors.primary),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error Scaffold ────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorScaffold({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        backgroundColor: context.sac.background,
        foregroundColor: context.sac.text,
        elevation: 0,
      ),
      body: Center(
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
                'No se pudo cargar la especialidad',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Revisa tu conexión e intenta de nuevo.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.sac.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SacButton.primary(
                text: 'Reintentar',
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
