import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/sac_brand_mark.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome_carousel_world.dart';

double welcomePageValue(PageController controller, int index) {
  if (!controller.hasClients || !controller.position.hasContentDimensions) {
    return index.toDouble();
  }
  return controller.page ?? index.toDouble();
}

/// Lámina 1: marca al centro del hueco (bajo Omitir, sobre el título).
/// Enter scale 0.96, 240ms ease-out. Sin FadeTransition sobre el PNG (Impeller).
class WelcomeSlideLogo extends StatefulWidget {
  const WelcomeSlideLogo({
    super.key,
    required this.controller,
    required this.index,
    required this.reduceMotion,
  });

  final PageController controller;
  final int index;
  final bool reduceMotion;

  @override
  State<WelcomeSlideLogo> createState() => _WelcomeSlideLogoState();
}

class _WelcomeSlideLogoState extends State<WelcomeSlideLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  bool _played = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: SacMotion.routeEnter,
    );
    if (widget.reduceMotion) {
      _enter.value = 1;
      _played = true;
    } else {
      widget.controller.addListener(_onPage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onPage();
      });
    }
  }

  @override
  void didUpdateWidget(WelcomeSlideLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion && !_played) {
      _enter.value = 1;
      _played = true;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPage);
    _enter.dispose();
    super.dispose();
  }

  void _onPage() {
    if (_played || widget.reduceMotion) return;
    final page = welcomePageValue(widget.controller, widget.index);
    if ((page - widget.index).abs() > 0.55) return;
    _played = true;
    widget.controller.removeListener(_onPage);
    _enter.forward();
  }

  double _markSize(BoxConstraints c) {
    final shortest = c.biggest.shortestSide;
    final grown = (shortest * 0.42).clamp(104.0, 148.0) * 1.4;
    final maxFit = math.min(c.maxWidth, c.maxHeight) * 0.9;
    return math.min(grown, maxFit);
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _enter, curve: SacMotion.easeOut);
    final chromeTop = MediaQuery.paddingOf(context).top + 48;

    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(top: chromeTop),
        child: LayoutBuilder(
          builder: (context, c) {
            final size = _markSize(c);
            return AnimatedBuilder(
              animation: Listenable.merge([widget.controller, _enter]),
              builder: (context, child) {
                final delta =
                    welcomePageValue(widget.controller, widget.index) -
                        widget.index;
                final parallax = widget.reduceMotion ? 0.0 : -delta * 18;
                final scale = widget.reduceMotion
                    ? 1.0
                    : SacMotion.enterScale +
                        (1 - SacMotion.enterScale) * curve.value;
                return Transform.translate(
                  offset: Offset(parallax, 0),
                  child: Center(
                    child: Transform.scale(scale: scale, child: child),
                  ),
                );
              },
              child: SacBrandMark(
                size: size,
                semanticLabel: 'welcome_carousel.slide1_eyebrow'.tr(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Stage extends StatefulWidget {
  const _Stage({
    required this.controller,
    required this.index,
    required this.reduceMotion,
    required this.kind,
    required this.scene,
  });

  final PageController controller;
  final int index;
  final bool reduceMotion;
  final WelcomeWorldKind kind;
  final List<Widget> Function(_Parallax p) scene;

  @override
  State<_Stage> createState() => _StageState();
}

class _Parallax {
  const _Parallax({
    required this.enter,
    required this.delta,
    required this.reduceMotion,
  });

  final double enter;
  final double delta;
  final bool reduceMotion;

  Offset layer(double depth) =>
      reduceMotion ? Offset.zero : Offset(-delta * depth, 0);

  double get scale => reduceMotion
      ? 1.0
      : SacMotion.enterScale + (1 - SacMotion.enterScale) * enter;

  double stagger(int i) {
    if (reduceMotion) return 1;
    final t = ((enter - i * 0.11) / 0.55).clamp(0.0, 1.0);
    return SacMotion.easeOut.transform(t);
  }
}

class _StageState extends State<_Stage> with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  bool _played = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: SacMotion.routeEnter,
    );
    if (widget.reduceMotion) {
      _enter.value = 1;
      _played = true;
    } else {
      widget.controller.addListener(_onPage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onPage();
      });
    }
  }

  @override
  void didUpdateWidget(_Stage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion && !_played) {
      _enter.value = 1;
      _played = true;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPage);
    _enter.dispose();
    super.dispose();
  }

  void _onPage() {
    if (_played || widget.reduceMotion) return;
    final page = welcomePageValue(widget.controller, widget.index);
    if ((page - widget.index).abs() > 0.55) return;
    _played = true;
    widget.controller.removeListener(_onPage);
    _enter.forward();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _enter, curve: SacMotion.easeOut);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.controller, _enter]),
        builder: (context, _) {
          final p = _Parallax(
            enter: curve.value,
            delta: welcomePageValue(widget.controller, widget.index) -
                widget.index,
            reduceMotion: widget.reduceMotion,
          );
          return ClipRect(
            child: Transform.scale(
              scale: p.scale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Transform.translate(
                      offset: p.layer(12),
                      child: CustomPaint(
                        painter: WelcomeWorldPainter(widget.kind),
                      ),
                    ),
                  ),
                  ...widget.scene(p),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: p.layer(34),
                      child: const CustomPaint(
                        painter: WelcomeFoliagePainter(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _prop(double t, Widget child) {
  final s = SacMotion.enterScale + (1 - SacMotion.enterScale) * t;
  return Transform.scale(
    scale: s,
    alignment: Alignment.center,
    child: child,
  );
}

class WelcomeSlideClubs extends StatelessWidget {
  const WelcomeSlideClubs({
    super.key,
    required this.controller,
    required this.index,
    required this.reduceMotion,
  });

  final PageController controller;
  final int index;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return _Stage(
      controller: controller,
      index: index,
      reduceMotion: reduceMotion,
      kind: WelcomeWorldKind.clubs,
      scene: (p) => [
        Align(
          alignment: const Alignment(-1.05, -0.05),
          child: Transform.translate(
            offset: p.layer(26),
            child: _prop(
              p.stagger(0),
              Transform.rotate(
                angle: -0.18,
                child: const WelcomeFlag(
                  cloth: WelcomeFlagCloth.aventureros,
                  emblem: WelcomeEmblem.aventureros,
                  height: 150,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(-1.02, 0.42),
          child: Transform.translate(
            offset: p.layer(22),
            child: _prop(
              p.stagger(1),
              Transform.rotate(
                angle: -0.08,
                child: const WelcomeFlag(
                  cloth: WelcomeFlagCloth.conquistadores,
                  emblem: WelcomeEmblem.conquistadores,
                  height: 132,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(1.08, 0.08),
          child: Transform.translate(
            offset: p.layer(24),
            child: _prop(
              p.stagger(2),
              Transform.rotate(
                angle: 0.2,
                child: const WelcomeFlag(
                  cloth: WelcomeFlagCloth.guiasMayores,
                  emblem: WelcomeEmblem.guiasMayores,
                  height: 148,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.08),
          child: Transform.translate(
            offset: p.layer(16),
            child: _prop(p.stagger(1), const _ClubsPhone()),
          ),
        ),
      ],
    );
  }
}

/// Lámina 2: splash collage (tipo loading Brawl Stars).
/// AV arriba, CQ abajo. Escalas, overlap, recorte de borde. Sin Guía Mayor.
/// Enter one-shot: stagger 60ms, 360ms ease-out. Sin drift infinito.
class WelcomeSlideClassPath extends StatelessWidget {
  const WelcomeSlideClassPath({
    super.key,
    required this.controller,
    required this.index,
    required this.reduceMotion,
  });

  static const aventureros = <String>[
    'assets/img/logos-clases/AV-01.png',
    'assets/img/logos-clases/AV-02.png',
    'assets/img/logos-clases/AV-03.png',
    'assets/img/logos-clases/AV-04.png',
    'assets/img/logos-clases/AV-05.png',
    'assets/img/logos-clases/AV-06.png',
  ];

  static const conquistadores = <String>[
    'assets/img/logos-clases/CQ-01.png',
    'assets/img/logos-clases/CQ-02.png',
    'assets/img/logos-clases/CQ-03.png',
    'assets/img/logos-clases/CQ-04.png',
    'assets/img/logos-clases/CQ-05.png',
    'assets/img/logos-clases/CQ-06.png',
  ];

  static const logos = [...aventureros, ...conquistadores];

  final PageController controller;
  final int index;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return _WelcomeSplashCollage(
      controller: controller,
      index: index,
      reduceMotion: reduceMotion,
      spots: _classPathSpots,
    );
  }
}

/// Lámina 3: mismo collage que clases, parches honor-*.png.
class WelcomeSlideHonors extends StatelessWidget {
  const WelcomeSlideHonors({
    super.key,
    required this.controller,
    required this.index,
    required this.reduceMotion,
  });

  final PageController controller;
  final int index;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return _WelcomeSplashCollage(
      controller: controller,
      index: index,
      reduceMotion: reduceMotion,
      spots: _honorSpots,
      interactive: true,
    );
  }
}

class _SplashSpot {
  const _SplashSpot({
    this.asset = '',
    this.tile,
    this.brandMark = false,
    required this.cx,
    required this.cy,
    required this.size,
    required this.rot,
    required this.depth,
  });

  final String asset;
  final _DashTileSpec? tile;
  final bool brandMark;
  final double cx;
  final double cy;
  final double size;
  final double rot;
  final int depth;

  _SplashSpot withAsset(String asset) => _SplashSpot(
        asset: asset,
        cx: cx,
        cy: cy,
        size: size,
        rot: rot,
        depth: depth,
      );
}

class _DashTileSpec {
  const _DashTileSpec({
    required this.icon,
    required this.labelKey,
    required this.color,
  });

  final List<List<dynamic>> icon;
  final String labelKey;
  final Color color;
}

/// Back → mid → front. Overlap y recorte de marco, no grilla.
const _classPathSpots = <_SplashSpot>[
  _SplashSpot(
    asset: 'assets/img/logos-clases/AV-04.png',
    cx: -0.02,
    cy: 0.30,
    size: 0.28,
    rot: -0.20,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/AV-06.png',
    cx: 1.04,
    cy: 0.28,
    size: 0.27,
    rot: 0.18,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/CQ-04.png',
    cx: -0.04,
    cy: 0.84,
    size: 0.26,
    rot: 0.16,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/CQ-06.png',
    cx: 1.05,
    cy: 0.80,
    size: 0.27,
    rot: -0.12,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/AV-02.png',
    cx: 0.50,
    cy: 0.08,
    size: 0.32,
    rot: 0.08,
    depth: 1,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/AV-05.png',
    cx: 0.38,
    cy: 0.40,
    size: 0.34,
    rot: -0.05,
    depth: 1,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/CQ-02.png',
    cx: 0.64,
    cy: 0.50,
    size: 0.30,
    rot: 0.11,
    depth: 1,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/AV-01.png',
    cx: 0.20,
    cy: 0.16,
    size: 0.44,
    rot: -0.10,
    depth: 2,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/AV-03.png',
    cx: 0.80,
    cy: 0.18,
    size: 0.42,
    rot: 0.12,
    depth: 2,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/CQ-01.png',
    cx: 0.22,
    cy: 0.64,
    size: 0.42,
    rot: -0.07,
    depth: 2,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/CQ-03.png',
    cx: 0.80,
    cy: 0.60,
    size: 0.40,
    rot: 0.06,
    depth: 2,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/CQ-05.png',
    cx: 0.50,
    cy: 0.76,
    size: 0.38,
    rot: -0.04,
    depth: 2,
  ),
];

/// Mismo layout que clases (12 huecos). 16 = CQ-03 (derecha). 15 = CQ-05 (abajo).
const _honorAssets = <String>[
  'assets/img/welcome/honor-4.png',
  'assets/img/welcome/honor-6.png',
  'assets/img/welcome/honor-13.png',
  'assets/img/welcome/honor-12.png',
  'assets/img/welcome/honor-2.png',
  'assets/img/welcome/honor-5.png',
  'assets/img/welcome/honor-8.png',
  'assets/img/welcome/honor-1.png',
  'assets/img/welcome/honor-18.png',
  'assets/img/welcome/honor-3.png',
  'assets/img/welcome/honor-16.png',
  'assets/img/welcome/honor-15.png',
];

final _honorSpots = [
  for (var i = 0; i < _classPathSpots.length; i++)
    _classPathSpots[i].withAsset(_honorAssets[i]),
];

/// Recuadros del dashboard. Sin rutas. Más chicos que clases: la card es opaca.
const _adminTiles = <_DashTileSpec>[
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedShield01,
    labelKey: 'dashboard.quick_access.insurance',
    color: AppColors.secondaryDark,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedPackage,
    labelKey: 'dashboard.quick_access.inventory',
    color: AppColors.accent,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedShoppingCart01,
    labelKey: 'dashboard.quick_access.materials',
    color: AppColors.info,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedCampfire,
    labelKey: 'dashboard.quick_access.camporees',
    color: AppColors.warning,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedCompass01,
    labelKey: 'dashboard.quick_access.units',
    color: AppColors.secondary,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedFiles01,
    labelKey: 'dashboard.quick_access.resources',
    color: AppColors.loginBrandBlue,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedAnalytics01,
    labelKey: 'dashboard.quick_access.reports',
    color: AppColors.info,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedBook01,
    labelKey: 'welcome_carousel.phone_docs',
    color: AppColors.colorViajero,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedCreditCard,
    labelKey: 'dashboard.quick_access.finances',
    color: AppColors.info,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedBookOpen01,
    labelKey: 'dashboard.quick_access.grouped_class',
    color: AppColors.primary,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedMedal05,
    labelKey: 'dashboard.quick_access.club_rankings',
    color: AppColors.primary,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedFolder01,
    labelKey: 'dashboard.quick_access.evidence_folder',
    color: AppColors.accent,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedCalendar02,
    labelKey: 'welcome_carousel.phone_calendar',
    color: AppColors.secondary,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedDashboardSquare01,
    labelKey: 'dashboard.quick_access.coordination',
    color: AppColors.info,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedTaskDone01,
    labelKey: 'welcome_carousel.slide4_record_reports',
    color: AppColors.secondaryDark,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedAward01,
    labelKey: 'dashboard.quick_access.my_ranking',
    color: AppColors.accent,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedChampion,
    labelKey: 'dashboard.quick_access.section_ranking',
    color: AppColors.primary,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedNoteEdit,
    labelKey: 'dashboard.quick_access.camporee_judge',
    color: AppColors.warning,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedClock01,
    labelKey: 'dashboard.stats.honors_in_progress',
    color: AppColors.loginBrandBlue,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedUserGroup,
    labelKey: 'dashboard.quick_access.members',
    color: AppColors.primary,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedBackpack03,
    labelKey: 'dashboard.quick_access.club',
    color: AppColors.secondary,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedUserCheck01,
    labelKey: 'welcome_carousel.phone_attendance',
    color: AppColors.loginBrandBlue,
  ),
  _DashTileSpec(
    icon: HugeIcons.strokeRoundedCalendar01,
    labelKey: 'welcome_carousel.slide4_record_activities',
    color: AppColors.accent,
  ),
];

const _adminLayout = <(double, double, double, double, int)>[
  (0.04, 0.16, 0.20, -0.14, 0),
  (0.96, 0.14, 0.20, 0.12, 0),
  (0.04, 0.90, 0.20, 0.10, 0),
  (0.90, 0.46, 0.20, 0.08, 0),
  (0.50, 0.08, 0.20, 0.05, 1),
  (0.30, 0.38, 0.20, -0.08, 1),
  (0.74, 0.32, 0.20, 0.08, 1),
  (0.50, 0.84, 0.24, -0.04, 1),
  (0.50, 0.46, 0.24, 0.03, 1),
  (0.34, 0.58, 0.22, -0.06, 1),
  (0.68, 0.56, 0.22, 0.07, 1),
  (0.50, 0.28, 0.22, -0.04, 1),
  (0.10, 0.48, 0.20, -0.10, 0),
  (0.66, 0.74, 0.22, 0.06, 1),
  (0.34, 0.78, 0.20, -0.05, 1),
  (0.88, 0.80, 0.20, 0.08, 0),
  (0.50, 0.64, 0.20, 0.02, 1),
  (0.82, 0.42, 0.20, 0.07, 1),
  (0.12, 0.34, 0.18, -0.12, 0),
  (0.20, 0.26, 0.28, -0.08, 2),
  (0.80, 0.24, 0.26, 0.08, 2),
  (0.20, 0.70, 0.28, -0.06, 2),
  (0.80, 0.64, 0.26, 0.05, 2),
];

final _adminSpots = [
  for (var i = 0; i < _adminTiles.length; i++)
    _SplashSpot(
      tile: _adminTiles[i],
      cx: _adminLayout[i].$1,
      cy: _adminLayout[i].$2,
      size: _adminLayout[i].$3,
      rot: _adminLayout[i].$4,
      depth: _adminLayout[i].$5,
    ),
];

/// Lámina 5: trayectoria. Piezas pedidas al frente; honores extra rellenan cream.
/// Sin clase GM instructor/avanzada (GM-02). Marca +30%. Collage +0.15 en Y.
const _journeySpots = <_SplashSpot>[
  _SplashSpot(
    asset: 'assets/img/welcome/honor-4.png',
    cx: 0.12,
    cy: 0.53,
    size: 0.18,
    rot: -0.16,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-13.png',
    cx: 0.38,
    cy: 0.25,
    size: 0.16,
    rot: 0.12,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-2.png',
    cx: 0.64,
    cy: 0.25,
    size: 0.16,
    rot: -0.10,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-1.png',
    cx: 0.12,
    cy: 0.79,
    size: 0.18,
    rot: -0.10,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-18.png',
    cx: 0.88,
    cy: 0.51,
    size: 0.18,
    rot: 0.12,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-3.png',
    cx: 0.36,
    cy: 0.73,
    size: 0.18,
    rot: -0.08,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-12.png',
    cx: 0.66,
    cy: 0.73,
    size: 0.18,
    rot: 0.08,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-8.png',
    cx: 0.34,
    cy: 0.88,
    size: 0.18,
    rot: -0.05,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-6.png',
    cx: 0.66,
    cy: 0.88,
    size: 0.18,
    rot: 0.06,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-5.png',
    cx: 0.88,
    cy: 0.79,
    size: 0.18,
    rot: 0.10,
    depth: 0,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-15.png',
    cx: 0.22,
    cy: 0.43,
    size: 0.22,
    rot: -0.12,
    depth: 1,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/honor-16.png',
    cx: 0.78,
    cy: 0.59,
    size: 0.22,
    rot: 0.12,
    depth: 1,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/masters-1.png',
    cx: 0.18,
    cy: 0.80,
    size: 0.24,
    rot: 0.10,
    depth: 1,
  ),
  _SplashSpot(
    asset: 'assets/img/welcome/masters-2.png',
    cx: 0.82,
    cy: 0.80,
    size: 0.24,
    rot: -0.08,
    depth: 1,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/AV-01.png',
    cx: 0.16,
    cy: 0.65,
    size: 0.24,
    rot: -0.08,
    depth: 1,
  ),
  _SplashSpot(
    asset: 'assets/img/logos-clases/CQ-01.png',
    cx: 0.84,
    cy: 0.67,
    size: 0.24,
    rot: 0.08,
    depth: 1,
  ),
  _SplashSpot(
    asset: WelcomeEmblem.aventureros,
    cx: 0.18,
    cy: 0.31,
    size: 0.24,
    rot: -0.06,
    depth: 2,
  ),
  _SplashSpot(
    asset: WelcomeEmblem.conquistadores,
    cx: 0.76,
    cy: 0.37,
    size: 0.24,
    rot: 0.06,
    depth: 2,
  ),
  _SplashSpot(
    asset: WelcomeEmblem.guiasMayores,
    cx: 0.50,
    cy: 0.31,
    size: 0.22,
    rot: 0.04,
    depth: 2,
  ),
  _SplashSpot(
    brandMark: true,
    cx: 0.50,
    cy: 0.57,
    size: 0.364,
    rot: 0,
    depth: 2,
  ),
];

class _WelcomeSplashCollage extends StatefulWidget {
  const _WelcomeSplashCollage({
    required this.controller,
    required this.index,
    required this.reduceMotion,
    required this.spots,
    this.interactive = false,
  });

  final PageController controller;
  final int index;
  final bool reduceMotion;
  final List<_SplashSpot> spots;
  final bool interactive;

  @override
  State<_WelcomeSplashCollage> createState() => _WelcomeSplashCollageState();
}

class _WelcomeSplashCollageState extends State<_WelcomeSplashCollage>
    with TickerProviderStateMixin {
  static const _enterMs = 360.0;
  static const _staggerMs = 60.0;
  static const _gravity = 2400.0;
  static const _bounce = 0.38;
  static const _restSpeed = 40.0;
  static const _maxFling = 2800.0;

  late final AnimationController _enter;
  late final Ticker _physics;
  bool _played = false;
  Duration _lastElapsed = Duration.zero;
  Size _playSize = Size.zero;
  int? _frontIndex;

  late List<Offset> _shift;
  late List<Offset> _vel;
  late List<bool> _awake;
  late List<bool> _dragging;

  List<_SplashSpot> get _spots => widget.spots;

  bool get _play => widget.interactive && !widget.reduceMotion;

  double get _enterTotalMs => _enterMs + _staggerMs * (_spots.length - 1);

  @override
  void initState() {
    super.initState();
    final n = _spots.length;
    _shift = List<Offset>.filled(n, Offset.zero);
    _vel = List<Offset>.filled(n, Offset.zero);
    _awake = List<bool>.filled(n, false);
    _dragging = List<bool>.filled(n, false);
    _physics = createTicker(_onPhysics);
    _enter = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _enterTotalMs.round()),
    );
    if (widget.reduceMotion) {
      _enter.value = 1;
      _played = true;
    } else {
      widget.controller.addListener(_onPage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onPage();
      });
    }
  }

  @override
  void didUpdateWidget(_WelcomeSplashCollage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion && !_played) {
      _enter.value = 1;
      _played = true;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPage);
    _physics.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _onPage() {
    if (_played || widget.reduceMotion) return;
    final page = welcomePageValue(widget.controller, widget.index);
    if ((page - widget.index).abs() > 0.55) return;
    _played = true;
    widget.controller.removeListener(_onPage);
    _enter.forward();
  }

  double _enterT(int i) {
    if (widget.reduceMotion || _awake[i]) return 1;
    final start = (i * _staggerMs) / _enterTotalMs;
    final end = (i * _staggerMs + _enterMs) / _enterTotalMs;
    final interval = Interval(
      start.clamp(0.0, 1.0),
      end.clamp(0.0, 1.0),
      curve: SacMotion.easeOut,
    );
    return interval.transform(_enter.value);
  }

  void _ensurePhysics() {
    if (_physics.isActive) return;
    _lastElapsed = Duration.zero;
    _physics.start();
  }

  void _onPanStart(int i) {
    setState(() {
      _awake[i] = true;
      _dragging[i] = true;
      _vel[i] = Offset.zero;
      _frontIndex = i;
    });
  }

  void _onPanUpdate(int i, DragUpdateDetails details) {
    setState(() {
      _shift[i] += details.delta;
    });
  }

  void _onPanEnd(int i, DragEndDetails details) {
    var velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance > _maxFling) {
      velocity = Offset.fromDirection(velocity.direction, _maxFling);
    }
    setState(() {
      _dragging[i] = false;
      _vel[i] = velocity;
    });
    _ensurePhysics();
  }

  void _onPhysics(Duration elapsed) {
    if (!mounted) return;
    final w = _playSize.width;
    final h = _playSize.height;
    if (w <= 0 || h <= 0) return;

    var dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.016;

    final minSide = math.min(w, h);
    var anyMoving = false;

    setState(() {
      for (var i = 0; i < _spots.length; i++) {
        if (!_awake[i] || _dragging[i]) continue;
        final spot = _spots[i];
        final size = minSide * spot.size;
        final restLeft = spot.cx * w - size / 2;
        final restTop = spot.cy * h - size / 2;
        var vel = _vel[i];
        vel += Offset(0, _gravity * dt);
        vel = Offset(
          vel.dx * math.exp(-0.9 * dt),
          vel.dy * math.exp(-0.25 * dt),
        );

        var left = restLeft + _shift[i].dx + vel.dx * dt;
        var top = restTop + _shift[i].dy + vel.dy * dt;
        final maxX = math.max(0.0, w - size);
        final maxY = math.max(0.0, h - size);

        if (left < 0) {
          left = 0;
          if (vel.dx < 0) vel = Offset(-vel.dx * _bounce, vel.dy);
        } else if (left > maxX) {
          left = maxX;
          if (vel.dx > 0) vel = Offset(-vel.dx * _bounce, vel.dy);
        }

        if (top < 0) {
          top = 0;
          if (vel.dy < 0) vel = Offset(vel.dx, -vel.dy * _bounce);
        } else if (top > maxY) {
          top = maxY;
          if (vel.dy > 0) {
            vel = Offset(vel.dx, -vel.dy * _bounce);
            if (vel.dy.abs() < _restSpeed) {
              vel = Offset(vel.dx * math.exp(-8 * dt), 0);
            }
          }
        }

        _shift[i] = Offset(left - restLeft, top - restTop);
        _vel[i] = vel;

        final onFloor = (maxY - top).abs() < 1.5;
        if (!onFloor || vel.distance > _restSpeed) {
          anyMoving = true;
        } else {
          _vel[i] = Offset.zero;
        }
      }
    });

    if (!anyMoving && !_dragging.contains(true)) {
      _physics.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget collage = ExcludeSemantics(
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.controller, _enter]),
        builder: (context, _) {
          final delta =
              welcomePageValue(widget.controller, widget.index) - widget.index;
          return LayoutBuilder(
            builder: (context, c) {
              _playSize = Size(c.maxWidth, c.maxHeight);
              final w = c.maxWidth;
              final h = c.maxHeight;
              final minSide = math.min(w, h);
              final indices = List<int>.generate(_spots.length, (i) => i);
              final front = _frontIndex;
              if (front != null) {
                indices.remove(front);
                indices.add(front);
              }
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final i in indices)
                    _placedLogo(
                      spot: _spots[i],
                      index: i,
                      w: w,
                      h: h,
                      minSide: minSide,
                      delta: delta,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
    if (!_play) {
      collage = IgnorePointer(child: collage);
    }
    return ClipRect(child: collage);
  }

  Widget _placedLogo({
    required _SplashSpot spot,
    required int index,
    required double w,
    required double h,
    required double minSide,
    required double delta,
  }) {
    final size = minSide * spot.size;
    final awake = _awake[index];
    final left = spot.cx * w - size / 2 + _shift[index].dx;
    final top = spot.cy * h - size / 2 + _shift[index].dy;
    final parallax =
        widget.reduceMotion || awake ? 0.0 : -delta * (8 + spot.depth * 16);
    final enter = _enterT(index);
    Widget child;
    if (spot.brandMark) {
      child = _BrandPosterMark(
        size: size,
        enter: enter,
        rot: spot.rot,
        depth: spot.depth,
        parallaxX: parallax,
        reduceMotion: widget.reduceMotion,
      );
    } else if (spot.tile != null) {
      child = _DashPosterTile(
        spec: spot.tile!,
        size: size,
        enter: enter,
        rot: spot.rot,
        depth: spot.depth,
        parallaxX: parallax,
        reduceMotion: widget.reduceMotion,
      );
    } else {
      child = _ClassPatternLogo(
        asset: spot.asset,
        size: size,
        enter: enter,
        rot: spot.rot,
        depth: spot.depth,
        parallaxX: parallax,
        reduceMotion: widget.reduceMotion,
      );
    }
    if (_play) {
      child = _HonorPlayHandle(
        onStart: () => _onPanStart(index),
        onUpdate: (details) => _onPanUpdate(index, details),
        onEnd: (details) => _onPanEnd(index, details),
        child: child,
      );
    }
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: child,
    );
  }
}

class _HonorPlayHandle extends StatelessWidget {
  const _HonorPlayHandle({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
  });

  final VoidCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
          EagerGestureRecognizer.new,
          (_) {},
        ),
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          PanGestureRecognizer.new,
          (instance) {
            instance.onStart = (_) => onStart();
            instance.onUpdate = onUpdate;
            instance.onEnd = onEnd;
          },
        ),
      },
      child: child,
    );
  }
}

class _BrandPosterMark extends StatelessWidget {
  const _BrandPosterMark({
    required this.size,
    required this.enter,
    required this.rot,
    required this.depth,
    required this.parallaxX,
    required this.reduceMotion,
  });

  final double size;
  final double enter;
  final double rot;
  final int depth;
  final double parallaxX;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final scale = reduceMotion
        ? 1.0
        : SacMotion.enterScale + (1 - SacMotion.enterScale) * enter;
    final lift = reduceMotion ? 0.0 : (1 - enter) * (8.0 + depth * 6.0);

    return Transform.translate(
      offset: Offset(parallaxX, lift),
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: scale,
          child: SacBrandMark(
            size: size,
            semanticLabel: 'welcome_carousel.slide1_eyebrow'.tr(),
          ),
        ),
      ),
    );
  }
}

class _ClassPatternLogo extends StatelessWidget {
  const _ClassPatternLogo({
    required this.asset,
    required this.size,
    required this.enter,
    required this.rot,
    required this.depth,
    required this.parallaxX,
    required this.reduceMotion,
  });

  final String asset;
  final double size;
  final double enter;
  final double rot;
  final int depth;
  final double parallaxX;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final cache =
        (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(64, 360);
    final opacity = reduceMotion ? 1.0 : (0.78 + 0.11 * depth) * enter;
    final scale = reduceMotion
        ? 1.0
        : SacMotion.enterScale + (1 - SacMotion.enterScale) * enter;
    final lift = reduceMotion ? 0.0 : (1 - enter) * (8.0 + depth * 6.0);

    return Transform.translate(
      offset: Offset(parallaxX, lift),
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: scale,
          child: Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            cacheWidth: cache,
            excludeFromSemantics: true,
            opacity: AlwaysStoppedAnimation(opacity.clamp(0.0, 1.0)),
          ),
        ),
      ),
    );
  }
}

class _DashPosterTile extends StatelessWidget {
  const _DashPosterTile({
    required this.spec,
    required this.size,
    required this.enter,
    required this.rot,
    required this.depth,
    required this.parallaxX,
    required this.reduceMotion,
  });

  final _DashTileSpec spec;
  final double size;
  final double enter;
  final double rot;
  final int depth;
  final double parallaxX;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final opacity = reduceMotion ? 1.0 : (0.78 + 0.11 * depth) * enter;
    final scale = reduceMotion
        ? 1.0
        : SacMotion.enterScale + (1 - SacMotion.enterScale) * enter;
    final lift = reduceMotion ? 0.0 : (1 - enter) * (8.0 + depth * 6.0);

    return Transform.translate(
      offset: Offset(parallaxX, lift),
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: spec.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: HugeIcon(
                          icon: spec.icon,
                          size: 24,
                          color: spec.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 96,
                        child: Text(
                          spec.labelKey.tr(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeSlideSash extends StatelessWidget {
  const WelcomeSlideSash({
    super.key,
    required this.controller,
    required this.index,
    required this.reduceMotion,
  });

  final PageController controller;
  final int index;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return _Stage(
      controller: controller,
      index: index,
      reduceMotion: reduceMotion,
      kind: WelcomeWorldKind.honors,
      scene: (p) => [
        Align(
          alignment: const Alignment(-0.95, 0.1),
          child: Transform.translate(
            offset: p.layer(22),
            child: _prop(
              p.stagger(0),
              Transform.rotate(
                angle: -1.05,
                child: Image.asset(
                  WelcomeEmblem.sash,
                  width: 168,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.98, 0.18),
          child: Transform.translate(
            offset: p.layer(20),
            child: _prop(p.stagger(2), const _HonorSashColumn()),
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.06),
          child: Transform.translate(
            offset: p.layer(16),
            child: _prop(p.stagger(1), const _HonorsPhone()),
          ),
        ),
      ],
    );
  }
}

class WelcomeSlideAdmin extends StatelessWidget {
  const WelcomeSlideAdmin({
    super.key,
    required this.controller,
    required this.index,
    required this.reduceMotion,
  });

  final PageController controller;
  final int index;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return _WelcomeSplashCollage(
      controller: controller,
      index: index,
      reduceMotion: reduceMotion,
      spots: _adminSpots,
    );
  }
}

/// Lámina 5: marca + clubes + una clase por ministerio + 2 honores + 2 masters.
class WelcomeSlideJourney extends StatelessWidget {
  const WelcomeSlideJourney({
    super.key,
    required this.controller,
    required this.index,
    required this.reduceMotion,
  });

  final PageController controller;
  final int index;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return _WelcomeSplashCollage(
      controller: controller,
      index: index,
      reduceMotion: reduceMotion,
      spots: _journeySpots,
    );
  }
}

class _ClubsPhone extends StatelessWidget {
  const _ClubsPhone();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = welcomeDeviceWidth(c);
        return WelcomeDevice(
          width: w,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
            child: Column(
              children: [
                const SacBrandMark(size: 28, elevated: false),
                const SizedBox(height: 6),
                Text(
                  'welcome_carousel.phone_church'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'welcome_carousel.phone_church_sub'.tr(),
                  style: TextStyle(
                    fontSize: 8.5,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _clubRow(
                  WelcomeEmblem.aventureros,
                  'welcome_carousel.ministry_adventurers'.tr(),
                  'welcome_carousel.club_av_line'.tr(),
                  const Color(0xFF1E6BB5),
                ),
                _clubRow(
                  WelcomeEmblem.conquistadores,
                  'welcome_carousel.ministry_pathfinders'.tr(),
                  'welcome_carousel.club_cq_line'.tr(),
                  const Color(0xFFC62828),
                ),
                _clubRow(
                  WelcomeEmblem.guiasMayores,
                  'welcome_carousel.ministry_master_guides'.tr(),
                  'welcome_carousel.club_gm_line'.tr(),
                  const Color(0xFF1B6B3A),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _clubRow(String asset, String title, String line, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          WelcomePng(asset: asset, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.lightTextSecondary,
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

class _HonorsPhone extends StatelessWidget {
  const _HonorsPhone();

  static const _dots = <(Color, HugeIconData)>[
    (AppColors.catDoctrinales, HugeIcons.strokeRoundedBook01),
    (AppColors.catMisioneras, HugeIcons.strokeRoundedFavourite),
    (AppColors.catNaturalezaBorde, HugeIcons.strokeRoundedTree01),
    (AppColors.catRecreativas, HugeIcons.strokeRoundedBackpack03),
    (AppColors.catCienciasSalud, HugeIcons.strokeRoundedFirstAidKit),
    (AppColors.catHabilidadesManuales, HugeIcons.strokeRoundedCamera01),
    (AppColors.catProfesionales, HugeIcons.strokeRoundedFirstAidKit),
    (AppColors.catDomesticas, HugeIcons.strokeRoundedMusicNote01),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = welcomeDeviceWidth(c);
        return WelcomeDevice(
          width: w,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
            child: Column(
              children: [
                const SacBrandMark(size: 24, elevated: false),
                const SizedBox(height: 4),
                Text(
                  'welcome_carousel.phone_my_honors'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final d in _dots)
                        Container(
                          decoration: BoxDecoration(
                            color: d.$1,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: buildIcon(
                              d.$2,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HonorSashColumn extends StatelessWidget {
  const _HonorSashColumn();

  static const _assets = [
    'assets/img/logos-clases/AV-01.png',
    'assets/img/logos-clases/AV-03.png',
    'assets/img/logos-clases/CQ-01.png',
    'assets/img/logos-clases/CQ-06.png',
    'assets/img/logos-clases/GM-01.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.12,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1F6B3C),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in _assets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: WelcomePng(asset: a, size: 28),
              ),
          ],
        ),
      ),
    );
  }
}
