import 'package:flutter/material.dart';
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
    final isLocked = item.status == ClassStatus.locked;
    final isDone = item.status == ClassStatus.done;
    final isExpired = item.status == ClassStatus.expired;
    final isLeft = widget.side == 'left';

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
                            colorFilter: isLocked
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
                            ),
                          ),
                          // Lock overlay
                          if (isLocked)
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
                                child: const Icon(Icons.lock,
                                    size: 18, color: Colors.black87),
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
                                child: Icon(
                                  isExpired ? Icons.history : Icons.check,
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
                          color: isLocked
                              ? RoadmapTokens.textMuted
                              : RoadmapTokens.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        item.age,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isLocked
                              ? RoadmapTokens.textLockedBg
                              : RoadmapTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent && item.progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'ACTUAL · ${item.progress!.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                if (isExpired)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: RoadmapTokens.statusExpired,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'VENCIDA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
