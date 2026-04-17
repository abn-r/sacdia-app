import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_section.dart';

/// Muestra el historial de transiciones de estado de una sección de evidencias.
///
/// Los datos disponibles son los snapshots de trazabilidad que trae la
/// entidad [EvidenceSection]: fecha/autor de envío, pre-aprobación LF y
/// validación de unión. No existe un array de historial completo en el
/// backend — el sheet refleja esto honestamente construyendo las entradas
/// a partir de los campos de trazabilidad disponibles.
///
/// Cuando [EvidenceSection.unionApproverName] es null (solo el campo local
/// actuó), se omite la entrada de validación de unión.
///
/// Llamar con [showEvidenceStatusHistorySheet].
class EvidenceStatusHistorySheet extends StatelessWidget {
  final EvidenceSection section;

  const EvidenceStatusHistorySheet({
    super.key,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final entries = _buildEntries();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedTime01,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Historial de estados',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        Text(
                          section.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 22,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: c.border),
            const SizedBox(height: 8),

            // Timeline de entradas o empty state
            if (entries.isEmpty)
              _EmptyState(c: c)
            else
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: _TimelineList(entries: entries, c: c),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Construye la lista de entradas a partir de los campos de trazabilidad
  /// disponibles en la entidad. El orden es cronológico.
  ///
  /// La entrada de validación de unión se omite cuando
  /// [EvidenceSection.unionApproverName] es null (solo LF actuó).
  List<_StatusEntry> _buildEntries() {
    final entries = <_StatusEntry>[];

    // Evento implícito de creación/inicio — siempre presente
    entries.add(
      _StatusEntry(
        label: 'Pendiente',
        description: 'Sección creada, esperando evidencias.',
        icon: HugeIcons.strokeRoundedClock01,
        color: AppColors.accent,
        author: null,
        timestamp: null,
      ),
    );

    // Evento de envío (si fue enviado alguna vez)
    final wasSubmitted = section.status == EvidenceSectionStatus.submitted ||
        section.status == EvidenceSectionStatus.validated ||
        section.status == EvidenceSectionStatus.rejected ||
        section.status == EvidenceSectionStatus.preapprovedLf;

    if (wasSubmitted) {
      entries.add(
        _StatusEntry(
          label: 'Enviado',
          description: 'Evidencias enviadas a validación.',
          icon: HugeIcons.strokeRoundedSent,
          color: AppColors.sacBlue,
          author: section.submittedByName,
          timestamp: section.submittedAt,
        ),
      );
    }

    // Evento de rechazo
    if (section.status == EvidenceSectionStatus.rejected) {
      entries.add(
        _StatusEntry(
          label: 'Rechazado',
          description: 'Sección rechazada. Podés reenviar evidencias.',
          icon: HugeIcons.strokeRoundedCancel01,
          color: AppColors.error,
          author: section.lfApproverName ?? section.validatedByName,
          timestamp: section.lfApprovedAt ?? section.validatedAt,
        ),
      );
      return entries;
    }

    // Evento de pre-aprobación LF (campo local actuó)
    if (section.status == EvidenceSectionStatus.preapprovedLf ||
        section.status == EvidenceSectionStatus.validated) {
      entries.add(
        _StatusEntry(
          label: 'Preaprobado',
          description: 'Sección pre-aprobada por el campo local.',
          icon: HugeIcons.strokeRoundedAnalytics01,
          color: AppColors.accentDark,
          author: section.lfApproverName,
          timestamp: section.lfApprovedAt,
        ),
      );
    }

    // Evento de validación final por unión — solo si union_approver está presente
    if (section.status == EvidenceSectionStatus.validated &&
        section.unionApproverName != null) {
      entries.add(
        _StatusEntry(
          label: 'Validado',
          description: 'Sección validada definitivamente por la unión.',
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
          color: AppColors.secondary,
          author: section.unionApproverName,
          timestamp: section.unionApprovedAt,
        ),
      );
    }

    return entries;
  }
}

// ── Entrada del timeline ──────────────────────────────────────────────────────

class _StatusEntry {
  final String label;
  final String description;
  final List<List<dynamic>> icon;
  final Color color;
  final String? author;
  final DateTime? timestamp;

  const _StatusEntry({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.author,
    required this.timestamp,
  });
}

// ── Lista con línea vertical de timeline ─────────────────────────────────────

class _TimelineList extends StatelessWidget {
  final List<_StatusEntry> entries;
  final SacColors c;

  const _TimelineList({required this.entries, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            isFirst: i == 0,
            isLast: i == entries.length - 1,
            c: c,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _StatusEntry entry;
  final bool isFirst;
  final bool isLast;
  final SacColors c;

  const _TimelineRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy · HH:mm', 'es');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Indicador lateral (dot + líneas) ───────────────────────────────
          SizedBox(
            width: 36,
            child: Column(
              children: [
                // Línea superior (ausente en el primer item)
                if (!isFirst)
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: entry.color.withValues(alpha: 0.35),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 6),

                // Dot con icono
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: entry.color.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: entry.icon,
                      size: 15,
                      color: entry.color,
                    ),
                  ),
                ),

                // Línea inferior (ausente en el último item)
                if (!isLast)
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: entry.color.withValues(alpha: 0.35),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Contenido del evento ────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 6 : 10,
                bottom: isLast ? 6 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Etiqueta del estado
                  Text(
                    entry.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: entry.color,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Descripción
                  Text(
                    entry.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  // Autor + timestamp (si existen)
                  if (entry.author != null || entry.timestamp != null) ...[
                    const SizedBox(height: 6),
                    _MetaRow(
                      author: entry.author,
                      timestamp: entry.timestamp,
                      dateFormat: dateFormat,
                      c: c,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String? author;
  final DateTime? timestamp;
  final DateFormat dateFormat;
  final SacColors c;

  const _MetaRow({
    required this.author,
    required this.timestamp,
    required this.dateFormat,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          if (author != null) ...[
            HugeIcon(
              icon: HugeIcons.strokeRoundedUser02,
              size: 13,
              color: c.textTertiary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                author!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (author != null && timestamp != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: c.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
          if (timestamp != null) ...[
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              size: 13,
              color: c.textTertiary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                dateFormat.format(timestamp!.toLocal()),
                style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final SacColors c;

  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedTime01,
            size: 48,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin cambios registrados',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Esta sección aún no tiene cambios de estado registrados.',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Helper de apertura ────────────────────────────────────────────────────────

/// Abre el [EvidenceStatusHistorySheet] como bottom sheet.
void showEvidenceStatusHistorySheet(
  BuildContext context, {
  required EvidenceSection section,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => EvidenceStatusHistorySheet(section: section),
  );
}
