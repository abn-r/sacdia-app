import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../classes/domain/entities/progressive_class.dart';
import '../../../classes/presentation/providers/classes_providers.dart';

// ── Estado visual de cada clase ──────────────────────────────────────────────

/// Los tres estados visuales que puede tener un logo de clase progresiva.
enum _ClassState {
  /// El usuario no está inscrito en esta clase.
  notEnrolled,

  /// El usuario está inscrito pero aún no fue investido (en progreso).
  inProgress,

  /// El usuario fue investido o alcanzó ≥ 80 % de progreso.
  invested,
}

enum _SheetStatus { invested, inProgress, notEnrolled, expired }

// ── Widget principal ─────────────────────────────────────────────────────────

class ClassStatusCircles extends ConsumerWidget {
  final String? clubType;

  const ClassStatusCircles({super.key, this.clubType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(userClassesProvider);
    final catalog = ref.watch(allClassesProvider).valueOrNull ?? const [];
    return classesAsync.when(
      data: (classes) => _buildContent(context, classes, catalog),
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Determine which logos to show based on clubType.
  List<_ClassLogoData> _getLogosForClubType() {
    final type = (clubType ?? '').toLowerCase();

    if (type.contains('aventurero')) {
      return const [
        _ClassLogoData('Corderitos', 'assets/img/logos-clases/AV-01.png',
            AppColors.colorCorderitos, 'domain.classes.lambs'),
        _ClassLogoData('Aves Madrugadoras', 'assets/img/logos-clases/AV-02.png',
            AppColors.colorCastores, 'domain.classes.eager_beavers'),
        _ClassLogoData(
            'Abejitas Industriosas',
            'assets/img/logos-clases/AV-03.png',
            AppColors.colorAbejas,
            'domain.classes.busy_bees'),
        _ClassLogoData('Rayos de Sol', 'assets/img/logos-clases/AV-04.png',
            AppColors.colorRayos, 'domain.classes.sunbeams'),
        _ClassLogoData('Constructores', 'assets/img/logos-clases/AV-05.png',
            AppColors.colorConstructores, 'domain.classes.builders'),
        _ClassLogoData('Manos Ayudadoras', 'assets/img/logos-clases/AV-06.png',
            AppColors.colorManos, 'domain.classes.helping_hands'),
      ];
    }

    if (type.contains('guía') || type.contains('guia')) {
      // Guías Mayores: all Conquistador classes + GM-01
      return const [
        _ClassLogoData('Amigo', 'assets/img/logos-clases/CQ-01.png',
            AppColors.colorAmigo, 'domain.classes.friend'),
        _ClassLogoData('Compañero', 'assets/img/logos-clases/CQ-02.png',
            AppColors.colorCompanero, 'domain.classes.companion'),
        _ClassLogoData('Explorador', 'assets/img/logos-clases/CQ-03.png',
            AppColors.colorExplorador, 'domain.classes.explorer'),
        _ClassLogoData('Orientador', 'assets/img/logos-clases/CQ-04.png',
            AppColors.colorOrientador, 'domain.classes.pioneer'),
        _ClassLogoData('Viajero', 'assets/img/logos-clases/CQ-05.png',
            AppColors.colorViajero, 'domain.classes.voyager'),
        _ClassLogoData('Guía', 'assets/img/logos-clases/CQ-06.png',
            AppColors.colorGuia, 'domain.classes.guide'),
        _ClassLogoData('Guía Mayor', 'assets/img/logos-clases/GM-01.png',
            AppColors.colorGuiaMayor, 'domain.classes.master_guide'),
      ];
    }

    // Default: Conquistadores
    return const [
      _ClassLogoData('Amigo', 'assets/img/logos-clases/CQ-01.png',
          AppColors.colorAmigo, 'domain.classes.friend'),
      _ClassLogoData('Compañero', 'assets/img/logos-clases/CQ-02.png',
          AppColors.colorCompanero, 'domain.classes.companion'),
      _ClassLogoData('Explorador', 'assets/img/logos-clases/CQ-03.png',
          AppColors.colorExplorador, 'domain.classes.explorer'),
      _ClassLogoData('Orientador', 'assets/img/logos-clases/CQ-04.png',
          AppColors.colorOrientador, 'domain.classes.pioneer'),
      _ClassLogoData('Viajero', 'assets/img/logos-clases/CQ-05.png',
          AppColors.colorViajero, 'domain.classes.voyager'),
      _ClassLogoData('Guía', 'assets/img/logos-clases/CQ-06.png',
          AppColors.colorGuia, 'domain.classes.guide'),
    ];
  }

  /// Determina el estado visual de un logo dado el enrollment resuelto.
  _ClassState _resolveState(ProgressiveClass? enrolled) {
    if (enrolled == null) return _ClassState.notEnrolled;

    final status = enrolled.investitureStatus?.toUpperCase();
    final progress = enrolled.overallProgress ?? 0;

    if (status == 'INVESTIDO' || progress >= 80) return _ClassState.invested;

    return _ClassState.inProgress;
  }

  Widget _buildContent(
    BuildContext context,
    List<ProgressiveClass> classes,
    List<ProgressiveClass> catalog,
  ) {
    final allLogos = _getLogosForClubType();
    final isGuiasMayores = (clubType ?? '').toLowerCase().contains('guía') ||
        (clubType ?? '').toLowerCase().contains('guia');

    // Separar: primeras 6 en fila, GM-01 arriba centrado
    final rowLogos = isGuiasMayores ? allLogos.sublist(0, 6) : allLogos;
    final gmLogo = isGuiasMayores ? allLogos.last : null;

    Widget logoWidget(_ClassLogoData logo) {
      final enrolled = _matchClass(logo, classes);
      return _ClassLogo(
        className: logo.displayName,
        assetPath: logo.assetPath,
        color: logo.color,
        state: _resolveState(enrolled),
        enrolled: enrolled,
        catalog: _matchClass(logo, catalog),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // GM-01 centrado arriba (solo Guías Mayores)
          if (gmLogo != null) ...[
            logoWidget(gmLogo),
            const SizedBox(height: 12),
          ],
          Row(
            children: rowLogos.map((logo) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: logoWidget(logo),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

ProgressiveClass? _matchClass(
  _ClassLogoData logo,
  List<ProgressiveClass> classes,
) {
  final code = logo.assetCode;
  for (final cls in classes) {
    if (cls.assetCode != null && cls.assetCode == code) return cls;
  }
  for (final cls in classes) {
    if (cls.name == logo.className) return cls;
  }
  return null;
}

// ── Data holder ──────────────────────────────────────────────────────────────

class _ClassLogoData {
  final String className;
  final String assetPath;
  final Color color;

  /// Translation key used for display. Falls back to [className] if not provided.
  final String? translationKey;

  const _ClassLogoData(this.className, this.assetPath, this.color,
      [this.translationKey]);

  String get displayName =>
      translationKey != null ? translationKey!.tr() : className;

  String get assetCode {
    final file = assetPath.split('/').last;
    final dot = file.lastIndexOf('.');
    return dot == -1 ? file : file.substring(0, dot);
  }
}

// ── Logo widget con soporte para los 3 estados ───────────────────────────────

class _ClassLogo extends StatelessWidget {
  final String className;
  final String assetPath;
  final _ClassState state;
  final Color color;
  final ProgressiveClass? enrolled;
  final ProgressiveClass? catalog;

  const _ClassLogo({
    required this.className,
    required this.assetPath,
    required this.state,
    required this.color,
    this.enrolled,
    this.catalog,
  });

  void _openSheet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: context.sac.surface,
      constraints: BoxConstraints.tightFor(width: width),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      builder: (ctx) => _ClassInfoSheet(
        displayName: className,
        assetPath: assetPath,
        color: color,
        enrolled: enrolled,
        catalog: catalog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const size = 52.0;

    return SacPressable(
      semanticLabel: className,
      onTap: () => _openSheet(context),
      child: SizedBox(
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _backgroundColor(context.sac),
                  border: Border.all(
                    color: _borderColor(context.sac),
                    width: _borderWidth,
                  ),
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _buildImage(context.sac),
                  ),
                ),
              ),
            ),
            if (state == _ClassState.inProgress)
              Positioned(
                bottom: -2,
                right: 4,
                child: _ProgressBadge(
                  progress: enrolled?.overallProgress ?? 0,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _backgroundColor(SacColors c) {
    return switch (state) {
      _ClassState.invested => color.withValues(alpha: 0.15),
      _ClassState.inProgress => color.withValues(alpha: 0.06),
      _ClassState.notEnrolled => c.surfaceVariant,
    };
  }

  Color _borderColor(SacColors c) {
    return switch (state) {
      _ClassState.invested => color,
      _ClassState.inProgress => color.withValues(alpha: 0.40),
      _ClassState.notEnrolled => c.border,
    };
  }

  double get _borderWidth {
    return switch (state) {
      _ClassState.invested => 2.0,
      _ClassState.inProgress => 1.5,
      _ClassState.notEnrolled => 1.0,
    };
  }

  static List<double> _grayscaleWithAlpha(double alpha) => <double>[
        0.2126, 0.7152, 0.0722, 0, 0, // R
        0.2126, 0.7152, 0.0722, 0, 0, // G
        0.2126, 0.7152, 0.0722, 0, 0, // B
        0, 0, 0, alpha, 0, // A
      ];

  Widget _buildImage(SacColors c) {
    if (state == _ClassState.invested) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        cacheWidth: 156,
        cacheHeight: 156,
        errorBuilder: (_, __, ___) => HugeIcon(
          icon: HugeIcons.strokeRoundedSecurityCheck,
          color: color,
          size: 24,
        ),
      );
    }

    final alpha = state == _ClassState.inProgress ? 0.5 : 0.25;

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_grayscaleWithAlpha(alpha)),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        cacheWidth: 156,
        cacheHeight: 156,
        errorBuilder: (_, __, ___) => HugeIcon(
          icon: HugeIcons.strokeRoundedSecurityCheck,
          color: c.textTertiary,
          size: 24,
        ),
      ),
    );
  }
}

class _ClassInfoSheet extends StatelessWidget {
  final String displayName;
  final String assetPath;
  final Color color;
  final ProgressiveClass? enrolled;
  final ProgressiveClass? catalog;

  const _ClassInfoSheet({
    required this.displayName,
    required this.assetPath,
    required this.color,
    this.enrolled,
    this.catalog,
  });

  _SheetStatus get _status {
    final investiture = enrolled?.investitureStatus?.toUpperCase();
    if (investiture == 'INVESTIDO') return _SheetStatus.invested;
    if (investiture == 'EXPIRED' || enrolled?.isExpired == true) {
      return _SheetStatus.expired;
    }
    if (enrolled != null) return _SheetStatus.inProgress;
    return _SheetStatus.notEnrolled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final minAge = enrolled?.minimumAge ?? catalog?.minimumAge;
    final description = enrolled?.description ?? catalog?.description;
    final year = enrolled?.ecclesiasticalYearLabel;
    final progress = enrolled?.overallProgress;
    final status = _status;
    final meta = <String>[
      if (minAge != null)
        'profile.view.class_sheet.min_age'.tr(namedArgs: {'age': '$minAge'}),
      if (status == _SheetStatus.inProgress && progress != null)
        'profile.view.class_sheet.progress'.tr(
          namedArgs: {'progress': '$progress'},
        ),
      if (year != null && year.isNotEmpty)
        'profile.view.class_sheet.year'.tr(namedArgs: {'year': year}),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => HugeIcon(
                    icon: HugeIcons.strokeRoundedSecurityCheck,
                    color: color,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -0.4,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: _statusColor(status, c),
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta.join(' · '),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: c.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(_SheetStatus status) {
    return switch (status) {
      _SheetStatus.invested => 'profile.view.class_sheet.status_invested'.tr(),
      _SheetStatus.inProgress =>
        'profile.view.class_sheet.status_in_progress'.tr(),
      _SheetStatus.notEnrolled =>
        'profile.view.class_sheet.status_not_enrolled'.tr(),
      _SheetStatus.expired => 'profile.view.class_sheet.status_expired'.tr(),
    };
  }

  Color _statusColor(_SheetStatus status, SacColors c) {
    return switch (status) {
      _SheetStatus.invested => c.success,
      _SheetStatus.inProgress => color,
      _SheetStatus.notEnrolled => c.textTertiary,
      _SheetStatus.expired => c.error,
    };
  }
}

class _ProgressBadge extends StatelessWidget {
  final int progress;
  final Color color;

  const _ProgressBadge({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Text(
        '$progress%',
        style: const TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
