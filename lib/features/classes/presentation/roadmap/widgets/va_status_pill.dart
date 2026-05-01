import 'package:flutter/material.dart';
import '../theme/roadmap_tokens.dart';

/// Pills de leyenda para la barra superior del roadmap.
class VAStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const VAStatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: RoadmapTokens.textPrimary),
          ),
        ],
      ),
    );
  }
}
