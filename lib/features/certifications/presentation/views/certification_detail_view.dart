import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_detail.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_module.dart';
import 'package:sacdia_app/features/certifications/domain/entities/user_certification.dart';

import '../providers/certifications_providers.dart';
import 'certification_progress_view.dart';

/// Detalle de una certificación: temario primero, inscripción al final.
///
/// La barra sigue el catálogo (superficie blanca). El título vive en el
/// cuerpo para poder partir en varias líneas. El conteo de módulos y
/// secciones se calcula del árbol, no de `modulesCount` del API.
class CertificationDetailView extends ConsumerWidget {
  final int certificationId;

  const CertificationDetailView({
    super.key,
    required this.certificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(certificationDetailProvider(certificationId));

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: 'certifications.list.title'.tr(),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _ErrorBody(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () =>
              ref.invalidate(certificationDetailProvider(certificationId)),
        ),
        data: (detail) => _DetailBody(
          detail: detail,
          certificationId: certificationId,
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final CertificationDetail detail;
  final int certificationId;

  const _DetailBody({
    required this.detail,
    required this.certificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCertificationsAsync = ref.watch(userCertificationsProvider);
    final enrollmentState =
        ref.watch(certificationEnrollmentNotifierProvider(certificationId));
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;
    final moduleCount = detail.modules.length;
    final sectionCount = detail.modules.fold<int>(
      0,
      (sum, module) => sum + module.sections.length,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CertificateMark(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        detail.name,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: c.text,
                                  letterSpacing: -0.4,
                                  height: 1.15,
                                ),
                      ),
                    ),
                  ],
                ),
                userCertificationsAsync.maybeWhen(
                  data: (userCertifications) {
                    final enrollment = _enrollmentOf(
                      userCertifications,
                      certificationId,
                    );
                    if (enrollment == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SacBadge.success(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                        label: 'certifications.detail.enrolled_meta'.tr(
                          namedArgs: {
                            'percentage': enrollment.progressPercentage
                                .toStringAsFixed(0),
                          },
                        ),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                if (detail.description != null &&
                    detail.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    detail.description!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: c.textSecondary,
                          height: 1.45,
                        ),
                  ),
                ],
                if (moduleCount > 0) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SacBadge(
                        icon: HugeIcons.strokeRoundedCheckList,
                        label: 'certifications.list.modules_count'.tr(
                          namedArgs: {'count': '$moduleCount'},
                        ),
                      ),
                      SacBadge(
                        icon: HugeIcons.strokeRoundedTaskDone01,
                        label: 'certifications.detail.sections_count'.tr(
                          namedArgs: {'count': '$sectionCount'},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckList,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'certifications.detail.modules'.tr(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 28),
              ],
            ),
          ),
        ),
        if (detail.modules.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
              child: Text(
                'certifications.detail.no_modules'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: SacCard(
                animate: true,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < detail.modules.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: c.border,
                          indent: 64,
                          endIndent: 16,
                        ),
                      _ModuleRow(
                        index: i + 1,
                        module: detail.modules[i],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 40),
            child: userCertificationsAsync.when(
              data: (userCertifications) {
                final enrollment = _enrollmentOf(
                  userCertifications,
                  certificationId,
                );
                if (enrollment != null) {
                  return SacButton.primary(
                    text: 'certifications.detail.view_progress'.tr(),
                    onPressed: () {
                      Navigator.push(
                        context,
                        SacSharedAxisRoute(
                          builder: (context) => CertificationProgressView(
                            enrollmentId: enrollment.enrollmentId,
                            certificationId: certificationId,
                          ),
                        ),
                      );
                    },
                  );
                }
                return SacButton.primary(
                  text: 'certifications.detail.enroll_cta'.tr(),
                  isLoading: enrollmentState.isLoading,
                  onPressed: () => _enroll(context, ref),
                );
              },
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: SacLoadingSmall()),
              ),
              error: (_, __) => SacButton.primary(
                text: 'certifications.detail.enroll_cta'.tr(),
                isLoading: enrollmentState.isLoading,
                onPressed: () => _enroll(context, ref),
              ),
            ),
          ),
        ),
      ],
    );
  }

  UserCertification? _enrollmentOf(
    List<UserCertification> userCertifications,
    int certificationId,
  ) {
    return userCertifications
        .where((uc) => uc.certificationId == certificationId)
        .firstOrNull;
  }

  Future<void> _enroll(BuildContext context, WidgetRef ref) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'certifications.detail.enroll_dialog_title'.tr(),
      content: 'certifications.detail.enroll_dialog_content'.tr(),
      confirmLabel: 'common.confirm'.tr(),
    );

    if (confirmed != true) return;

    final success = await ref
        .read(
          certificationEnrollmentNotifierProvider(certificationId).notifier,
        )
        .enroll();

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('certifications.detail.enroll_success'.tr()),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final message = ref
            .read(certificationEnrollmentNotifierProvider(certificationId))
            .errorMessage ??
        'certifications.errors.enroll_certification'.tr();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _CertificateMark extends StatelessWidget {
  const _CertificateMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedCertificate01,
          size: 22,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ModuleRow extends StatefulWidget {
  final int index;
  final CertificationModule module;

  const _ModuleRow({
    required this.index,
    required this.module,
  });

  @override
  State<_ModuleRow> createState() => _ModuleRowState();
}

class _ModuleRowState extends State<_ModuleRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expand;
  late final Animation<double> _expandFactor;
  late final Animation<double> _chevronTurns;
  bool _expanded = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
    );
    _expandFactor = CurvedAnimation(
      parent: _expand,
      curve: SacMotion.easeOut,
    );
    _chevronTurns = Tween<double>(begin: 0, end: 0.5).animate(_expandFactor);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    _expand.duration = reduce ? Duration.zero : SacMotion.standard;
  }

  @override
  void dispose() {
    _expand.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expand.forward();
    } else {
      _expand.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final sectionCount = widget.module.sections.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: widget.module.name,
          hint: 'certifications.detail.sections_count'.tr(
            namedArgs: {'count': '$sectionCount'},
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: _toggle,
            child: AnimatedContainer(
              duration: reduce ? Duration.zero : SacMotion.press,
              curve: SacMotion.easeOut,
              color: _pressed
                  ? c.surfaceVariant
                  : _expanded
                      ? AppColors.primarySurface
                      : Colors.transparent,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: reduce ? Duration.zero : SacMotion.standard,
                    curve: SacMotion.easeOut,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _expanded
                          ? AppColors.primary
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: reduce ? Duration.zero : SacMotion.standard,
                        curve: SacMotion.easeOut,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _expanded ? Colors.white : AppColors.primary,
                        ),
                        child: Text('${widget.index}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.module.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                    height: 1.25,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'certifications.detail.sections_count'.tr(
                            namedArgs: {'count': '$sectionCount'},
                          ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _expanded
                                        ? AppColors.primaryDark
                                        : c.textTertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: _chevronTurns,
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      size: 16,
                      color: _expanded ? AppColors.primary : c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandFactor,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: _expandFactor,
            child: _ModuleSections(module: widget.module),
          ),
        ),
      ],
    );
  }
}

class _ModuleSections extends StatelessWidget {
  final CertificationModule module;

  const _ModuleSections({required this.module});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (module.sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Text(
          'certifications.detail.no_sections_module'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.textSecondary,
              ),
        ),
      );
    }

    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          for (final section in module.sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                            height: 1.35,
                          ),
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

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
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
              'certifications.detail.load_error'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: context.sac.textSecondary,
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
    );
  }
}
