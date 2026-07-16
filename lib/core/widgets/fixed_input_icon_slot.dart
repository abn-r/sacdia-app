import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Renders a HugeIcon in the fixed slot used by text-field decorations.
class FixedInputIconSlot extends StatelessWidget {
  static const constraints = BoxConstraints.tightFor(width: 48, height: 48);

  final HugeIconData icon;
  final Color color;
  final double iconSize;
  final Key? iconSlotKey;

  const FixedInputIconSlot({
    super.key,
    required this.icon,
    required this.color,
    this.iconSize = 20,
    this.iconSlotKey,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        key: iconSlotKey,
        width: iconSize,
        height: iconSize,
        child: HugeIcon(icon: icon, color: color, size: iconSize),
      ),
    );
  }
}
