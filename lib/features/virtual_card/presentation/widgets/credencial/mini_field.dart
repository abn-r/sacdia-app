import 'package:flutter/material.dart';

/// Etiqueta micro + valor — usado en el grid 2×2 dentro de la zona blanca del QR.
class MiniField extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlight;
  const MiniField({
    super.key,
    required this.label,
    required this.value,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            height: 1.1,
            color: Color(0xFF9AA0AB),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: highlight ?? const Color(0xFF0F1115),
            ),
          ),
        ),
      ],
    );
  }
}
