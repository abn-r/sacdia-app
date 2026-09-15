import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Shell tab glyph. Package ships stroke-only icons, so selected state
/// is weight, not a filled sibling.
class SacNavIcon extends StatelessWidget {
  const SacNavIcon({
    super.key,
    required this.icon,
    this.selected = false,
    this.size = 24,
    this.color,
  });

  final List<List<dynamic>> icon;
  final bool selected;
  final double size;
  final Color? color;

  static const double idleStroke = 1.5;
  static const double selectedStroke = 2.25;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: icon,
      size: size,
      color: color,
      strokeWidth: selected ? selectedStroke : idleStroke,
    );
  }
}
