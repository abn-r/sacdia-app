import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/utils/responsive.dart';

/// Logos de ministerio flotando en los laterales del login, agrupados
/// en la banda superior (nunca debajo de los text fields).
///
/// Decorativo: [IgnorePointer] + [ExcludeSemantics]. Idle = seno a 3200ms
/// (fuera de ~0.2 Hz). Opacidad vía [Image.opacity] — Impeller no acepta
/// FadeTransition/Opacity anidados sobre PNG.
class LoginClubConstellation extends StatefulWidget {
  const LoginClubConstellation({super.key});

  static const aventureros = 'assets/img/logo_aventureros_color.png';
  static const conquistadores = 'assets/img/logo_conquistadores_color.png';
  static const guiasMayores = 'assets/img/logo-guias-mayores.png';
  static const jovenesAdventistas = 'assets/img/logo-ja.png';

  @override
  State<LoginClubConstellation> createState() => _LoginClubConstellationState();
}

class _EmblemSpec {
  const _EmblemSpec({
    required this.asset,
    required this.phase,
    required this.index,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });

  final String asset;
  final double phase;
  final int index;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
}

class _LoginClubConstellationState extends State<LoginClubConstellation>
    with TickerProviderStateMixin {
  static const _enterSpan = 200.0;
  static const _staggerMs = 40.0;
  static const _enterTotalMs = 320.0;
  static const _amplitude = 6.0;
  static const _rotation = 0.035;
  static const _idleOpacity = 1.0;
  static const _reducedOpacity = 1.0;

  late final AnimationController _enter;
  late final AnimationController _drift;
  late final AnimationController _visibility;
  late final CurvedAnimation _visibilityCurve;
  bool _keyboardHidden = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _drift = AnimationController(
      vsync: this,
      duration: SacMotion.idleDrift,
    );
    // Keyboard hide — same duration as the old AnimatedOpacity. Kept as its
    // own controller so Image.opacity is the only opacity applied to the PNG
    // (Impeller rejects nested FadeTransition/Opacity on Image contents).
    _visibility = AnimationController(
      vsync: this,
      duration: SacMotion.reducedFade,
      value: 1,
    );
    _visibilityCurve = CurvedAnimation(
      parent: _visibility,
      curve: SacMotion.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    final compactLandscape =
        Responsive.isLandscape(context) && Responsive.isCompactHeight(context);

    if (reduce || compactLandscape) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }

    if (reduce) {
      _enter.duration = SacMotion.reducedFade;
    } else {
      _enter.duration = const Duration(milliseconds: 320);
    }
    if (!_enter.isCompleted) {
      _enter.forward();
    }

    final hideForKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (hideForKeyboard != _keyboardHidden) {
      _keyboardHidden = hideForKeyboard;
      if (hideForKeyboard) {
        _visibility.reverse();
      } else {
        _visibility.forward();
      }
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _drift.dispose();
    _visibilityCurve.dispose();
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Responsive.isLandscape(context) &&
        Responsive.isCompactHeight(context)) {
      return const SizedBox.shrink();
    }

    final reduce = SacMotion.reduceMotionOf(context);
    final safe = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final size = (width < 360
            ? 52.0
            : width >= 600
                ? 72.0
                : 64.0) *
        1.3;

    final specs = <_EmblemSpec>[
      _EmblemSpec(
        asset: LoginClubConstellation.aventureros,
        phase: 0.00,
        index: 0,
        left: -18,
        top: safe.top + 8,
      ),
      _EmblemSpec(
        asset: LoginClubConstellation.conquistadores,
        phase: 0.25,
        index: 1,
        right: -18,
        top: safe.top + 36,
      ),
      _EmblemSpec(
        asset: LoginClubConstellation.guiasMayores,
        phase: 0.50,
        index: 2,
        left: 8,
        top: safe.top + 104,
      ),
      _EmblemSpec(
        asset: LoginClubConstellation.jovenesAdventistas,
        phase: 0.75,
        index: 3,
        right: 8,
        top: safe.top + 132,
      ),
    ];

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final spec in specs)
              Positioned(
                left: spec.left,
                right: spec.right,
                top: spec.top,
                bottom: spec.bottom,
                width: size,
                height: size,
                child: _Emblem(
                  spec: spec,
                  size: size,
                  reduceMotion: reduce,
                  enter: _enter,
                  drift: _drift,
                  visibility: _visibilityCurve,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({
    required this.spec,
    required this.size,
    required this.reduceMotion,
    required this.enter,
    required this.drift,
    required this.visibility,
  });

  final _EmblemSpec spec;
  final double size;
  final bool reduceMotion;
  final AnimationController enter;
  final AnimationController drift;
  final Animation<double> visibility;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * dpr).round().clamp(64, 256);

    final start = (spec.index * _LoginClubConstellationState._staggerMs) /
        _LoginClubConstellationState._enterTotalMs;
    final end = (spec.index * _LoginClubConstellationState._staggerMs +
            _LoginClubConstellationState._enterSpan) /
        _LoginClubConstellationState._enterTotalMs;
    final interval = Interval(
      start.clamp(0.0, 1.0),
      end.clamp(0.0, 1.0),
      curve: SacMotion.easeOut,
    );

    final targetOpacity = reduceMotion
        ? _LoginClubConstellationState._reducedOpacity
        : _LoginClubConstellationState._idleOpacity;

    return AnimatedBuilder(
      animation: Listenable.merge([enter, drift, visibility]),
      builder: (context, _) {
        final enterT = reduceMotion
            ? SacMotion.easeOut.transform(enter.value)
            : interval.transform(enter.value);
        final opacity =
            (enterT * targetOpacity * visibility.value).clamp(0.0, 1.0);

        Widget child = Image.asset(
          spec.asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          cacheWidth: cacheSize,
          excludeFromSemantics: true,
          opacity: AlwaysStoppedAnimation(opacity),
        );

        child = DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.24 * opacity),
                offset: const Offset(0, 6),
                blurRadius: 16,
              ),
            ],
          ),
          child: child,
        );

        if (reduceMotion) return child;

        final scale = Tween<double>(
          begin: SacMotion.enterScale,
          end: 1.0,
        ).transform(enterT);
        child = Transform.scale(scale: scale, child: child);

        final t = (drift.value + spec.phase) % 1.0;
        final dy =
            math.sin(t * 2 * math.pi) * _LoginClubConstellationState._amplitude;
        final rot = math.sin(t * 2 * math.pi + 0.8) *
            _LoginClubConstellationState._rotation;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: rot,
            child: child,
          ),
        );
      },
    );
  }
}
