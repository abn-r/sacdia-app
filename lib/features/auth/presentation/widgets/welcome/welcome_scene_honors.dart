import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_assets.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_common.dart';

class _Slot {
  const _Slot(this.honor, this.x, this.y, this.size, this.index, this.isStar);

  final int honor;
  final double x;
  final double y;
  final double size;
  final int index;
  final bool isStar;
}

/// Scene 3: 23 honors in a 5-4-5-4-5 honeycomb burst from the centre and bob,
/// with a search pill typing real honor names underneath.
class WelcomeSceneHonors extends StatelessWidget {
  const WelcomeSceneHonors({super.key, required this.active});

  final bool active;

  static const List<(int, double)> _rows = [
    (5, 50),
    (4, 123),
    (5, 196),
    (4, 269),
    (5, 342),
  ];
  static const double _size = 86;
  static const double _pitch = 90;
  static const double _starSize = 116;
  static const int _starHonor = 15;
  static const double _hubX = 201;
  static const double _hubY = 196;
  static const double _fadeHeight = 34;
  static const double _typeStep = 0.11;
  static const int _hold = 6;
  static const Curve _burst = Cubic(0.2, 1.2, 0.4, 1);

  static final List<_Slot> _slots = _buildSlots();

  static List<_Slot> _buildSlots() {
    final pool = [
      for (var n = 1; n <= 23; n++)
        if (n != _starHonor) n,
    ];
    final slots = <_Slot>[];
    var k = 0;
    var index = 0;
    for (var r = 0; r < _rows.length; r++) {
      final (count, y) = _rows[r];
      for (var c = 0; c < count; c++) {
        final x = _hubX + (c - (count - 1) / 2) * _pitch;
        final isStar = r == 2 && c == 2;
        slots.add(
          _Slot(
            isStar ? _starHonor : pool[k++],
            x,
            y,
            isStar ? _starSize : _size,
            index,
            isStar,
          ),
        );
        index++;
      }
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final words = [
      for (var i = 1; i <= 6; i++) 'welcome_carousel.s3_word$i'.tr(),
    ];
    return WelcomeSceneFrame(
      child: WelcomeStage(
        active: active,
        builder: (context, clock) {
          final t = clock.t;
          final reduced = clock.reduced;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                    stops: [0, _fadeHeight / 440],
                  ).createShader(rect),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final slot in _slots.where((s) => !s.isStar))
                        _honor(slot, t, reduced),
                      for (final slot in _slots.where((s) => s.isStar))
                        _honor(slot, t, reduced),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                top: 386,
                height: 52,
                child: _SearchPill(
                  text: reduced ? words.first : _typed(words, t),
                  showCaret: reduced || (t % 1.0) < 0.5,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _honor(_Slot s, double t, bool reduced) {
    final delay = s.isStar ? 0.0 : 0.12 + s.index * 0.04;
    final burst = reduced ? 1.0 : _burst.transform(wProg(t, delay, 0.9));
    final bob = reduced ? 0.0 : wPingPong(t, 2 * (3 + (s.index % 6) * 0.5));
    return Positioned(
      left: s.x - s.size / 2 + (1 - burst) * (_hubX - s.x),
      top: s.y - s.size / 2 + (1 - burst) * (_hubY - s.y),
      width: s.size,
      height: s.size,
      child: Opacity(
        opacity: burst.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: wLerp(0.15, 1, burst),
          child: Transform.translate(
            offset: Offset(0, -7 * bob),
            child: Transform.rotate(
              angle: 3 * bob * math.pi / 180,
              child: welcomeHonor(s.honor, s.size),
            ),
          ),
        ),
      ),
    );
  }

  /// Types and deletes the words, one step every [_typeStep] seconds.
  static String _typed(List<String> words, double t) {
    var total = 0;
    for (final word in words) {
      total += 2 * (word.length + _hold + 1);
    }
    var step = (t / _typeStep).floor() % total;
    var w = 0;
    while (true) {
      final word = words[w % words.length];
      final cycle = 2 * (word.length + _hold + 1);
      if (step < cycle) {
        final half = word.length + _hold + 1;
        final c = step < half ? step + 1 : cycle - step - 1;
        return word.substring(0, math.min(c, word.length));
      }
      step -= cycle;
      w++;
    }
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.text, required this.showCaret});

  final String text;
  final bool showCaret;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 20,
              color: c.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: theme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: c.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Opacity(
                    opacity: showCaret ? 1 : 0,
                    child: const SizedBox(
                      width: 2,
                      height: 20,
                      child: DecoratedBox(
                        decoration:
                            BoxDecoration(color: AppColors.loginBrandBlue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.infoContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  'welcome_carousel.s3_count'.tr(),
                  style: theme.bodySmall?.copyWith(
                    fontSize: SacFontSize.bodySmall,
                    fontWeight: FontWeight.w600,
                    color: c.onInfoContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
