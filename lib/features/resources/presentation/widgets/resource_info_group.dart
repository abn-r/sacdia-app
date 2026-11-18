import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// One label/value pair of [ResourceInfoGroup]. [logoAsset] precedes the value.
class ResourceInfoRow {
  const ResourceInfoRow({
    required this.label,
    required this.value,
    this.logoAsset,
  });

  final String label;
  final String value;
  final String? logoAsset;
}

/// Bordered card of label/value rows ("Categoría: Clases"). Renders nothing
/// when there are no rows, so callers just omit rows that have no data.
class ResourceInfoGroup extends StatelessWidget {
  const ResourceInfoGroup({super.key, required this.rows});

  final List<ResourceInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final c = context.sac;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
            _InfoRow(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row});

  final ResourceInfoRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                row.label,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (row.logoAsset != null) ...[
                      Image.asset(
                        row.logoAsset!,
                        width: 20,
                        height: 20,
                        cacheWidth: 60,
                        cacheHeight: 60,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
