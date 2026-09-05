import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/class_requirement.dart';
import '../utils/status_meta.dart';
import 'status_glyph.dart';

/// Fila compacta de un requerimiento dentro de un módulo expandido.
///
/// Layout: StatusGlyph 22×22 · título · meta (label + archivos) · chevron.
/// Tap → abre pantalla de detalle.
///
/// Handoff §5.10: padding 12v·16r·20l·12b, borderBottom ink100, gap 12.
class RequirementCard extends StatelessWidget {
  final ClassRequirement requirement;
  final VoidCallback onTap;

  const RequirementCard({
    super.key,
    required this.requirement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = StatusMeta.of(requirement.status);
    final c = context.sac;

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.coral200.withValues(alpha: 0.4),
      highlightColor: AppColors.coral50.withValues(alpha: 0.5),
      child: Container(
        padding: const EdgeInsets.only(
          top: 12,
          bottom: 12,
          left: 20,
          right: 16,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: c.ink100, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading: StatusGlyph 22×22
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: StatusGlyph(status: requirement.status),
            ),

            const SizedBox(width: 12),

            // Middle: title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    requirement.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: c.ink800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _ReqMetaRow(
                    meta: meta,
                    filesUploaded: requirement.files.length,
                    filesRequired: requirement.maxFiles,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Trailing: chevron right
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 14,
                color: c.ink300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Meta row ──────────────────────────────────────────────────────────────────

class _ReqMetaRow extends StatelessWidget {
  final StatusMeta meta;
  final int filesUploaded;
  final int filesRequired;

  const _ReqMetaRow({
    required this.meta,
    required this.filesUploaded,
    required this.filesRequired,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status label
        Text(
          meta.label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: meta.dark,
          ),
        ),

        // Dot separator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '·',
            style: TextStyle(
              fontSize: 11.5,
              color: c.ink300,
            ),
          ),
        ),

        // Files count: "X/Y archivos"
        Text(
          '$filesUploaded',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: c.ink800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          '/$filesRequired archivos',
          style: TextStyle(
            fontSize: 11.5,
            color: c.ink400,
          ),
        ),
      ],
    );
  }
}
