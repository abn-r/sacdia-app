import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../data/roadmap_data.dart';
import '../theme/roadmap_tokens.dart';

/// Nodo individual del roadmap: imagen-escudo + label + badges.
class VANode extends StatefulWidget {
  final ClassItem item;
  final String side; // 'left' | 'right' — alternancia zigzag
  final Color accentColor;
  final VoidCallback? onTap;

  const VANode({
    super.key,
    required this.item,
    required this.side,
    required this.accentColor,
    this.onTap,
  });

  @override
  State<VANode> createState() => _VANodeState();
}

class _VANodeState extends State<VANode> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isCurrent = item.status == ClassStatus.current;
    final isUpcoming = item.status == ClassStatus.upcoming;
    final isNotTaken = item.status == ClassStatus.notTaken;
    final isDone = item.status == ClassStatus.done;
    final isExpired = item.status == ClassStatus.expired;
    final isLockedLook = isUpcoming || isNotTaken;
    final isLeft = widget.side == 'left';
    final shieldCacheSize = (RoadmapTokens.nodeShieldSize * 3).round();
    final ageLabel = item.minimumAge != null
        ? 'classes.roadmap.min_age'.tr(
            namedArgs: {'age': '${item.minimumAge}'},
          )
        : item.age;

    return Padding(
      padding: EdgeInsets.only(
        left:
            isLeft ? RoadmapTokens.nodePadInside : RoadmapTokens.nodePadOutside,
        right:
            isLeft ? RoadmapTokens.nodePadOutside : RoadmapTokens.nodePadInside,
        bottom: RoadmapTokens.nodeRowGap,
      ),
      child: Align(
        alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 148,
            child: Column(
              children: [
                // Escudo (imagen) con halo de pulso si es actual
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (isCurrent)
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Container(
                          width: 144 + _pulse.value * 16,
                          height: 144 + _pulse.value * 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                widget.accentColor.withValues(alpha: 0.33),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Ring estático sobre el escudo cuando es la clase actual.
                    // Coexiste con el halo pulsante: halo = glow suave,
                    // ring = borde duro que señala sin animación.
                    if (isCurrent)
                      Container(
                        width: RoadmapTokens.nodeShieldSize +
                            RoadmapTokens.currentRingStrokeWidth * 2 +
                            4,
                        height: RoadmapTokens.nodeShieldSize +
                            RoadmapTokens.currentRingStrokeWidth * 2 +
                            4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.accentColor,
                            width: RoadmapTokens.currentRingStrokeWidth,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: RoadmapTokens.nodeShieldSize,
                      height: RoadmapTokens.nodeShieldSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Sombra debajo del escudo
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: -4,
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Imagen escudo
                          ColorFiltered(
                            colorFilter: isLockedLook
                                ? const ColorFilter.matrix(<double>[
                                    0.33,
                                    0.33,
                                    0.33,
                                    0,
                                    0,
                                    0.33,
                                    0.33,
                                    0.33,
                                    0,
                                    0,
                                    0.33,
                                    0.33,
                                    0.33,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    .55,
                                    0,
                                  ])
                                : const ColorFilter.mode(
                                    Colors.transparent, BlendMode.dst),
                            child: Image.asset(
                              item.img,
                              fit: BoxFit.contain,
                              width: RoadmapTokens.nodeShieldSize,
                              height: RoadmapTokens.nodeShieldSize,
                              cacheWidth: shieldCacheSize,
                              cacheHeight: shieldCacheSize,
                            ),
                          ),
                          // Lock overlay — no cursada y por cursar
                          if (isLockedLook)
                            Center(
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedLocked,
                                    size: 18,
                                    color: Colors.black87),
                              ),
                            ),
                          // Done check
                          if (isDone || isExpired)
                            Positioned(
                              right: 6,
                              bottom: -2,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: isExpired
                                      ? RoadmapTokens.statusExpired
                                      : RoadmapTokens.statusDone,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: HugeIcon(
                                  icon: isExpired
                                      ? HugeIcons
                                          .strokeRoundedTransactionHistory
                                      : HugeIcons.strokeRoundedTick02,
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
                const SizedBox(height: 12),
                // Label translúcido
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.9)),
                    boxShadow: RoadmapTokens.labelCardShadow,
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isLockedLook
                              ? RoadmapTokens.textMuted
                              : RoadmapTokens.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        ageLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isLockedLook
                              ? RoadmapTokens.textLockedBg
                              : RoadmapTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  _NodeChip(
                    label: 'classes.roadmap.node_current'.tr(namedArgs: {
                      'progress': (item.progress ?? 0).toStringAsFixed(0),
                    }),
                    color: widget.accentColor,
                  ),
                if (isNotTaken)
                  _NodeChip(
                    label: 'classes.roadmap.node_not_taken'.tr(),
                    color: RoadmapTokens.statusNotTaken,
                  ),
                if (isUpcoming)
                  _NodeChip(
                    label: 'classes.roadmap.node_upcoming'.tr(),
                    color: RoadmapTokens.statusUpcoming,
                  ),
                if (isExpired)
                  _NodeChip(
                    label: 'classes.roadmap.node_expired'.tr(),
                    color: RoadmapTokens.statusExpired,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _NodeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
