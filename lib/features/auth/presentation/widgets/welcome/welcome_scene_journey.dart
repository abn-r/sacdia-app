import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_assets.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_common.dart';

enum _EventKind { investiture, certificate, honors }

class _Event {
  const _Event.investiture(this.side, this.top, this.classCode, this.nameKey,
      {this.glow = false})
      : kind = _EventKind.investiture,
        delay = 0,
        honors = const [];

  const _Event.certificate(this.side, this.top, this.nameKey)
      : kind = _EventKind.certificate,
        delay = 0.2,
        classCode = null,
        glow = false,
        honors = const [];

  const _Event.honors(this.side, this.top, this.nameKey, this.honors)
      : kind = _EventKind.honors,
        delay = 0.2,
        classCode = null,
        glow = false;

  final _EventKind kind;
  final String side;
  final double top;
  final String? classCode;
  final String nameKey;
  final List<int> honors;
  final double delay;
  final bool glow;
}

class _Year {
  const _Year(this.label, this.top, {this.gold = false});

  final int label;
  final double top;
  final bool gold;
}

/// Scene 5: a vertical timeline that scrolls up in steps. Each year has an
/// investiture, a certificate or a set of honors; a big faint year counts in
/// the background and the final Master Guide card wears a gold ring.
class WelcomeSceneJourney extends StatelessWidget {
  const WelcomeSceneJourney({super.key, required this.active});

  final bool active;

  static const double _loop = 12;
  static const double _spineHeight = 760;
  static const double _cardWidth = 156;
  static const double _gutter = 22;
  static const double _bigYearSize = 120;
  static const double _bigYearTrack = -6;
  static const double _yearStep = 2.4;
  static const Curve _scrollCurve = Cubic(0.65, 0, 0.35, 1);

  static const List<int> _bigYears = [2021, 2022, 2023, 2024, 2026];

  static const List<_Year> _years = [
    _Year(2021, 10),
    _Year(2022, 150),
    _Year(2023, 290),
    _Year(2024, 430),
    _Year(2026, 570, gold: true),
  ];

  static const List<_Event> _events = [
    _Event.investiture('r', 0, 'CQ-01', 's5_class_friend'),
    _Event.honors('l', 50, 's5_honors_3', [1, 2, 3]),
    _Event.investiture('l', 140, 'CQ-02', 's5_class_companion'),
    _Event.certificate('r', 190, 's5_cert_first_aid'),
    _Event.investiture('r', 280, 'CQ-03', 's5_class_explorer'),
    _Event.honors('l', 330, 's5_honors_5', [4, 5, 6, 8]),
    _Event.investiture('l', 420, 'CQ-05', 's5_class_voyager'),
    _Event.certificate('r', 470, 's5_cert_unit_leader'),
    _Event.investiture('r', 560, 'GM-01', 's5_class_master_guide', glow: true),
    _Event.honors('l', 610, 's5_honors_full', [9, 10, 12, 13]),
  ];

  @override
  Widget build(BuildContext context) {
    return WelcomeSceneFrame(
      child: WelcomeStage(
        active: active,
        builder: (context, clock) {
          final reduced = clock.reduced;
          final t = clock.t;
          final phase = (t % _loop) / _loop;
          final scroll = reduced
              ? -30.0
              : wKeyframes(
                  phase,
                  const [
                    (0, 250),
                    (0.06, 250),
                    (0.2, 110),
                    (0.24, 110),
                    (0.38, -30),
                    (0.42, -30),
                    (0.56, -170),
                    (0.6, -170),
                    (0.74, -310),
                    (0.92, -310),
                    (1, 250),
                  ],
                  curve: _scrollCurve,
                );
          final bigYear = reduced
              ? _bigYears.last
              : _bigYears[(t / _yearStep).floor() % _bigYears.length];

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -6,
                top: 150,
                child: ExcludeSemantics(
                  child: Text(
                    '$bigYear',
                    style: TextStyle(
                      fontSize: _bigYearSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: _bigYearTrack,
                      height: 1,
                      color: context.sac.text.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0, 0.12, 0.85, 1],
                  ).createShader(rect),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: scroll,
                        height: _spineHeight,
                        child: _timeline(context, t, reduced),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _timeline(BuildContext context, double t, bool reduced) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 199.5,
          top: 0,
          width: 3,
          height: _spineHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(AppTheme.radiusHairline),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.loginBrandBlue, AppColors.loginBrandGold],
              ),
            ),
          ),
        ),
        for (final year in _years) _YearPill(year: year),
        for (final event in _events)
          _positioned(event, _eventOpacityScale(event, t, reduced)),
      ],
    );
  }

  (double, double) _eventOpacityScale(_Event e, double t, bool reduced) {
    if (reduced) return (1, 1);
    final local = t - e.delay;
    if (local < 0) return (0, 0.9);
    final p = (local % _loop) / _loop;
    final opacity = wKeyframes(
      p,
      const [(0, 0), (0.06, 1), (0.94, 1), (1, 0)],
      curve: Curves.ease,
    );
    final scale = wKeyframes(p, const [(0, 0.9), (0.06, 1), (1, 1)]);
    return (opacity, scale);
  }

  Widget _positioned(_Event e, (double, double) os) {
    final (opacity, scale) = os;
    final isLeft = e.side == 'l';
    return Positioned(
      top: e.top,
      width: _cardWidth,
      left: isLeft ? 201 - _gutter - _cardWidth : 201 + _gutter,
      child: opacity <= 0
          ? const SizedBox(height: 1)
          : Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: RepaintBoundary(child: _EventCard(event: e)),
              ),
            ),
    );
  }
}

class _YearPill extends StatelessWidget {
  const _YearPill({required this.year});

  final _Year year;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final bg = year.gold ? AppColors.loginBrandGold : AppColors.loginBrandBlue;
    final fg = year.gold ? c.ink900 : c.onPrimary;
    return Positioned(
      top: year.top,
      left: 0,
      right: 0,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            boxShadow: [BoxShadow(color: c.background, spreadRadius: 5)],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              '${year.label}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: SacFontSize.bodySmall,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: fg,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final _Event event;

  static const double _thumb = 34;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final overline = theme.labelSmall?.copyWith(
      fontSize: SacFontSize.caption,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: c.textTertiary,
    );
    final title = theme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: c.text,
    );

    Widget textBlock(String kindKey) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'welcome_carousel.$kindKey'.tr().toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: overline,
              ),
              Text(
                'welcome_carousel.${event.nameKey}'.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: title,
              ),
            ],
          ),
        );

    final Widget content;
    switch (event.kind) {
      case _EventKind.investiture:
        content = Row(
          children: [
            welcomeClassBadge(event.classCode!, 40),
            const SizedBox(width: 8),
            textBlock('s5_investiture'),
          ],
        );
      case _EventKind.certificate:
        content = Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.warningContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCertificate01,
                    size: 22,
                    color: c.onWarningContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            textBlock('s5_certificate'),
          ],
        );
      case _EventKind.honors:
        final n = event.honors.length;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'welcome_carousel.s5_honors'.tr().toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: overline,
            ),
            Text(
              'welcome_carousel.${event.nameKey}'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: title,
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: _thumb,
              width: _thumb * n - _overlap * (n - 1),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < n; i++)
                    Positioned(
                      left: i * (_thumb - _overlap),
                      child: welcomeHonor(event.honors[i], _thumb),
                    ),
                ],
              ),
            ),
          ],
        );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
        boxShadow: event.glow
            ? [
                const BoxShadow(
                  color: AppColors.loginBrandGold,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.loginBrandGold.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Padding(padding: const EdgeInsets.all(10), child: content),
    );
  }
}
