import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
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

// ── Widget principal ─────────────────────────────────────────────────────────

class ClassStatusCircles extends ConsumerWidget {
  final String? clubType;

  const ClassStatusCircles({super.key, this.clubType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(userClassesProvider);
    return classesAsync.when(
      data: (classes) => _buildContent(context, classes),
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Determine which logos to show based on clubType.
  List<_ClassLogoData> _getLogosForClubType() {
    final type = (clubType ?? '').toLowerCase();

    if (type.contains('aventurero')) {
      return const [
        _ClassLogoData('Corderitos', 'assets/img/logos-clases/AV-01.png', AppColors.colorCorderitos, 'domain.classes.lambs'),
        _ClassLogoData('Aves Madrugadoras', 'assets/img/logos-clases/AV-02.png', AppColors.colorCastores, 'domain.classes.eager_beavers'),
        _ClassLogoData('Abejitas Industriosas', 'assets/img/logos-clases/AV-03.png', AppColors.colorAbejas, 'domain.classes.busy_bees'),
        _ClassLogoData('Rayos de Sol', 'assets/img/logos-clases/AV-04.png', AppColors.colorRayos, 'domain.classes.sunbeams'),
        _ClassLogoData('Constructores', 'assets/img/logos-clases/AV-05.png', AppColors.colorConstructores, 'domain.classes.builders'),
        _ClassLogoData('Manos Ayudadoras', 'assets/img/logos-clases/AV-06.png', AppColors.colorManos, 'domain.classes.helping_hands'),
      ];
    }

    if (type.contains('guía') || type.contains('guia')) {
      // Guías Mayores: all Conquistador classes + GM-01
      return const [
        _ClassLogoData('Amigo', 'assets/img/logos-clases/CQ-01.png', AppColors.colorAmigo, 'domain.classes.friend'),
        _ClassLogoData('Compañero', 'assets/img/logos-clases/CQ-02.png', AppColors.colorCompanero, 'domain.classes.companion'),
        _ClassLogoData('Explorador', 'assets/img/logos-clases/CQ-03.png', AppColors.colorExplorador, 'domain.classes.explorer'),
        _ClassLogoData('Orientador', 'assets/img/logos-clases/CQ-04.png', AppColors.colorOrientador, 'domain.classes.pioneer'),
        _ClassLogoData('Viajero', 'assets/img/logos-clases/CQ-05.png', AppColors.colorViajero, 'domain.classes.voyager'),
        _ClassLogoData('Guía', 'assets/img/logos-clases/CQ-06.png', AppColors.colorGuia, 'domain.classes.guide'),
        _ClassLogoData('Guía Mayor', 'assets/img/logos-clases/GM-01.png', AppColors.colorGuiaMayor, 'domain.classes.master_guide'),
      ];
    }

    // Default: Conquistadores
    return const [
      _ClassLogoData('Amigo', 'assets/img/logos-clases/CQ-01.png', AppColors.colorAmigo, 'domain.classes.friend'),
      _ClassLogoData('Compañero', 'assets/img/logos-clases/CQ-02.png', AppColors.colorCompanero, 'domain.classes.companion'),
      _ClassLogoData('Explorador', 'assets/img/logos-clases/CQ-03.png', AppColors.colorExplorador, 'domain.classes.explorer'),
      _ClassLogoData('Orientador', 'assets/img/logos-clases/CQ-04.png', AppColors.colorOrientador, 'domain.classes.pioneer'),
      _ClassLogoData('Viajero', 'assets/img/logos-clases/CQ-05.png', AppColors.colorViajero, 'domain.classes.voyager'),
      _ClassLogoData('Guía', 'assets/img/logos-clases/CQ-06.png', AppColors.colorGuia, 'domain.classes.guide'),
    ];
  }

  /// Determina el estado visual de un logo dado el conjunto de clases enrolladas.
  _ClassState _resolveState(
    _ClassLogoData logo,
    Map<String, ProgressiveClass> enrolledByName,
  ) {
    final enrolled = enrolledByName[logo.className];
    if (enrolled == null) return _ClassState.notEnrolled;

    final status = enrolled.investitureStatus?.toUpperCase();
    final progress = enrolled.overallProgress ?? 0;

    if (status == 'INVESTIDO' || progress >= 80) return _ClassState.invested;

    return _ClassState.inProgress;
  }

  Widget _buildContent(BuildContext context, List<ProgressiveClass> classes) {
    // Índice por nombre para O(1) lookup al resolver el estado de cada logo.
    final enrolledByName = {for (final c in classes) c.name: c};

    final allLogos = _getLogosForClubType();
    final isGuiasMayores =
        (clubType ?? '').toLowerCase().contains('guía') ||
        (clubType ?? '').toLowerCase().contains('guia');

    // Separar: primeras 6 en fila, GM-01 arriba centrado
    final rowLogos = isGuiasMayores ? allLogos.sublist(0, 6) : allLogos;
    final gmLogo = isGuiasMayores ? allLogos.last : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // GM-01 centrado arriba (solo Guías Mayores)
          if (gmLogo != null) ...[
            _ClassLogo(
              className: gmLogo.className,
              assetPath: gmLogo.assetPath,
              color: gmLogo.color,
              state: _resolveState(gmLogo, enrolledByName),
              translationKey: gmLogo.translationKey,
              classId: enrolledByName[gmLogo.className]?.id,
              fallbackProgress:
                  enrolledByName[gmLogo.className]?.overallProgress,
            ),
            const SizedBox(height: 12),
          ],

          // Fila de 6 clases — FittedBox evita overflow en pantallas angostas
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: rowLogos.map((logo) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _ClassLogo(
                    className: logo.className,
                    assetPath: logo.assetPath,
                    color: logo.color,
                    state: _resolveState(logo, enrolledByName),
                    translationKey: logo.translationKey,
                    classId: enrolledByName[logo.className]?.id,
                    fallbackProgress:
                        enrolledByName[logo.className]?.overallProgress,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data holder ──────────────────────────────────────────────────────────────

class _ClassLogoData {
  final String className;
  final String assetPath;
  final Color color;

  /// Translation key used for display. Falls back to [className] if not provided.
  final String? translationKey;

  const _ClassLogoData(this.className, this.assetPath, this.color, [this.translationKey]);

  String get displayName => translationKey != null ? translationKey!.tr() : className;
}

// ── Logo widget con soporte para los 3 estados ───────────────────────────────

class _ClassLogo extends ConsumerWidget {
  final String className;
  final String assetPath;
  final _ClassState state;
  final Color color;
  final String? translationKey;

  /// ID de la clase para obtener el progreso preciso desde
  /// [classWithProgressProvider]. Null cuando el usuario no está inscrito.
  final int? classId;

  /// Progreso de respaldo (0-100) proveniente del enrollment record.
  /// Se muestra mientras [classWithProgressProvider] carga o en error.
  final int? fallbackProgress;

  const _ClassLogo({
    required this.className,
    required this.assetPath,
    required this.state,
    required this.color,
    this.translationKey,
    this.classId,
    this.fallbackProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve accurate progress from classWithProgressProvider when enrolled,
    // falling back to the enrollment overallProgress while loading or on error.
    final int progress;
    if (classId != null && state == _ClassState.inProgress) {
      final classProgressAsync = ref.watch(classWithProgressProvider(classId!));
      progress = classProgressAsync.when(
        data: (cwp) => cwp.completionPercent,
        loading: () => fallbackProgress ?? 0,
        error: (_, __) => fallbackProgress ?? 0,
      );
    } else {
      progress = fallbackProgress ?? 0;
    }
    final c = context.sac;
    const size = 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Círculo principal ─────────────────────────────────────────
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _backgroundColor(c),
                border: Border.all(
                  color: _borderColor(c),
                  width: _borderWidth,
                ),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _buildImage(c),
                ),
              ),
            ),

            // ── Badge de progreso (solo estado inProgress) ────────────────
            if (state == _ClassState.inProgress)
              Positioned(
                bottom: -2,
                right: -2,
                child: _ProgressBadge(
                  progress: progress,
                  color: color,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: size + 8,
          child: Text(
            translationKey != null ? translationKey!.tr() : className,
            style: TextStyle(
              fontSize: 9,
              fontWeight: state == _ClassState.invested
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: state == _ClassState.invested ? color : c.textTertiary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Helpers de estilo ─────────────────────────────────────────────────────

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

  // Builds a grayscale+alpha matrix embedding opacity directly into the
  // ColorFilter, avoiding an Opacity widget that would create an offscreen
  // compositing layer. Row 3 (alpha) multiplier is set to [alpha].
  static List<double> _grayscaleWithAlpha(double alpha) => <double>[
    0.2126, 0.7152, 0.0722, 0,     0, // R
    0.2126, 0.7152, 0.0722, 0,     0, // G
    0.2126, 0.7152, 0.0722, 0,     0, // B
    0,      0,      0,      alpha, 0, // A
  ];

  Widget _buildImage(SacColors c) {
    // invested: imagen a todo color, sin filtros.
    if (state == _ClassState.invested) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.shield_outlined,
          color: color,
          size: 24,
        ),
      );
    }

    // inProgress y notEnrolled: desaturamos con ColorFiltered (grayscale real)
    // y diferenciamos con opacidad: 50 % en progreso, 25 % no inscrito.
    // La opacidad se codifica en la fila alpha de la matriz — sin Opacity widget.
    final alpha = state == _ClassState.inProgress ? 0.5 : 0.25;

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_grayscaleWithAlpha(alpha)),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.shield_outlined,
          color: c.textTertiary,
          size: 24,
        ),
      ),
    );
  }
}

// ── Badge de porcentaje para el estado inProgress ────────────────────────────

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
