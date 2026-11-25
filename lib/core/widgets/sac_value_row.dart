import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/sac_colors.dart';

/// A label and its value on one row, inside a [SacGroupedSection]
/// (details of a request, device data of a report).
class SacValueRow extends StatelessWidget {
  const SacValueRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // The label keeps its natural width up to half the row and wraps
        // beyond that (long label, large text), so it never overflows.
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (constraints.maxWidth - 16) / 2,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    color: c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
